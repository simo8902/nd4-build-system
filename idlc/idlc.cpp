#include <algorithm>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

struct Token {
    std::string text;
    std::size_t line = 1;
    std::size_t column = 1;
    bool end = false;
};

class IdlcError final : public std::runtime_error {
public:
    explicit IdlcError(const std::string& message) : std::runtime_error(message) {}
};

class Lexer {
public:
    explicit Lexer(std::string source) : source_(std::move(source)) {}

    std::vector<Token> Lex() {
        std::vector<Token> tokens;
        while (position_ < source_.size()) {
            SkipIgnored();
            if (position_ >= source_.size()) {
                break;
            }
            const std::size_t line = line_;
            const std::size_t column = column_;
            const char current = source_[position_];
            if (std::isalpha(static_cast<unsigned char>(current)) || current == '_') {
                const std::size_t start = position_;
                Advance();
                while (position_ < source_.size()) {
                    const char value = source_[position_];
                    if (!std::isalnum(static_cast<unsigned char>(value)) && value != '_') {
                        break;
                    }
                    Advance();
                }
                tokens.push_back({source_.substr(start, position_ - start), line, column, false});
                continue;
            }
            if (std::isdigit(static_cast<unsigned char>(current))) {
                const std::size_t start = position_;
                Advance();
                while (position_ < source_.size()) {
                    const char value = source_[position_];
                    if (!std::isalnum(static_cast<unsigned char>(value))) {
                        break;
                    }
                    Advance();
                }
                tokens.push_back({source_.substr(start, position_ - start), line, column, false});
                continue;
            }
            if (current == '<' && Peek(1) == '<') {
                Advance();
                Advance();
                tokens.push_back({"<<", line, column, false});
                continue;
            }
            if (std::string("{}[];:.@=|+-*/()").find(current) != std::string::npos) {
                Advance();
                tokens.push_back({std::string(1, current), line, column, false});
                continue;
            }
            Fail(line, column, std::string("unexpected character '") + current + "'");
        }
        tokens.push_back({"", line_, column_, true});
        return tokens;
    }

private:
    char Peek(std::size_t offset) const {
        if (position_ + offset >= source_.size()) {
            return '\0';
        }
        return source_[position_ + offset];
    }

    void Advance() {
        if (position_ >= source_.size()) {
            return;
        }
        if (source_[position_] == '\n') {
            ++line_;
            column_ = 1;
        } else {
            ++column_;
        }
        ++position_;
    }

    void SkipIgnored() {
        for (;;) {
            while (position_ < source_.size() &&
                   std::isspace(static_cast<unsigned char>(source_[position_]))) {
                Advance();
            }
            if (position_ + 1 >= source_.size() || source_[position_] != '/') {
                return;
            }
            if (source_[position_ + 1] == '/') {
                while (position_ < source_.size() && source_[position_] != '\n') {
                    Advance();
                }
                continue;
            }
            if (source_[position_ + 1] == '*') {
                Advance();
                Advance();
                bool closed = false;
                while (position_ < source_.size()) {
                    if (source_[position_] == '*' && Peek(1) != '\0' && source_[position_ + 1] == '/') {
                        Advance();
                        Advance();
                        closed = true;
                        break;
                    }
                    Advance();
                }
                if (!closed) {
                    Fail(line_, column_, "unterminated block comment");
                }
                continue;
            }
            return;
        }
    }

    [[noreturn]] void Fail(std::size_t line, std::size_t column, const std::string& message) const {
        throw IdlcError("line " + std::to_string(line) + ", column " + std::to_string(column) + ": " + message);
    }

    std::string source_;
    std::size_t position_ = 0;
    std::size_t line_ = 1;
    std::size_t column_ = 1;
};

struct EnumValue {
    std::string name;
    std::string expression;
};

struct EnumDefinition {
    std::string name;
    std::string backend = "both";
    std::string underlyingType;
    std::vector<EnumValue> values;
};

struct FieldDefinition {
    std::string type;
    std::string name;
    std::size_t arrayCount = 1;
};

struct StructDefinition {
    std::string name;
    std::string layout;
    std::vector<FieldDefinition> fields;
};

struct Schema {
    std::string module;
    std::vector<EnumDefinition> enums;
    std::vector<StructDefinition> structs;
};

class Parser {
public:
    explicit Parser(std::vector<Token> tokens) : tokens_(std::move(tokens)) {}

    Schema Parse() {
        Schema schema;
        Expect("module");
        schema.module = ParseQualifiedName();
        Expect(";");
        while (!Current().end) {
            if (Match("enum")) {
                schema.enums.push_back(ParseEnum());
            } else if (Match("struct")) {
                schema.structs.push_back(ParseStruct());
            } else {
                Fail("expected enum or struct declaration");
            }
        }
        Validate(schema);
        return schema;
    }

private:
    const Token& Current() const {
        return tokens_[index_];
    }

    bool Match(const std::string& text) {
        if (Current().text != text) {
            return false;
        }
        ++index_;
        return true;
    }

    void Expect(const std::string& text) {
        if (!Match(text)) {
            Fail("expected '" + text + "'");
        }
    }

    std::string ConsumeIdentifier(const std::string& description) {
        const Token token = Current();
        if (token.end || token.text.empty() ||
            (!std::isalpha(static_cast<unsigned char>(token.text.front())) && token.text.front() != '_')) {
            Fail("expected " + description);
        }
        ++index_;
        return token.text;
    }

    std::string ParseQualifiedName() {
        std::string result = ConsumeIdentifier("module name");
        while (Match(".")) {
            result += ".";
            result += ConsumeIdentifier("module name segment");
        }
        return result;
    }

    EnumDefinition ParseEnum() {
        EnumDefinition definition;
        definition.name = ConsumeIdentifier("enum name");
        if (Match("@")) {
            definition.backend = ConsumeIdentifier("enum backend");
        }
        Expect(":");
        definition.underlyingType = ConsumeIdentifier("enum underlying type");
        Expect("{");
        std::set<std::string> names;
        while (!Match("}")) {
            if (Current().end) {
                Fail("unterminated enum");
            }
            EnumValue value;
            value.name = ConsumeIdentifier("enum value name");
            Expect("=");
            value.expression = ParseExpression();
            Expect(";");
            if (!names.insert(value.name).second) {
                Fail("duplicate enum value '" + value.name + "'");
            }
            definition.values.push_back(std::move(value));
        }
        Expect(";");
        if (definition.values.empty()) {
            Fail("enum '" + definition.name + "' must contain at least one value");
        }
        return definition;
    }

    StructDefinition ParseStruct() {
        StructDefinition definition;
        definition.name = ConsumeIdentifier("struct name");
        Expect("@");
        definition.layout = ConsumeIdentifier("struct layout");
        Expect("{");
        std::set<std::string> names;
        while (!Match("}")) {
            if (Current().end) {
                Fail("unterminated struct");
            }
            FieldDefinition field;
            field.type = ConsumeIdentifier("field type");
            field.name = ConsumeIdentifier("field name");
            if (Match("[")) {
                const Token countToken = Current();
                const std::string count = countToken.text;
                if (countToken.end || count.empty() ||
                    !std::all_of(count.begin(), count.end(), [](char value) {
                        return std::isdigit(static_cast<unsigned char>(value)) != 0;
                    })) {
                    Fail("array size must be a positive integer");
                }
                ++index_;
                try {
                    field.arrayCount = std::stoull(count);
                } catch (const std::exception&) {
                    Fail("array size is out of range");
                }
                if (field.arrayCount == 0) {
                    Fail("array size must be positive");
                }
                Expect("]");
            }
            Expect(";");
            if (!names.insert(field.name).second) {
                Fail("duplicate field '" + field.name + "' in struct '" + definition.name + "'");
            }
            definition.fields.push_back(std::move(field));
        }
        Expect(";");
        if (definition.fields.empty()) {
            Fail("struct '" + definition.name + "' must contain at least one field");
        }
        return definition;
    }

    std::string ParseExpression() {
        std::string expression;
        bool hasToken = false;
        while (Current().text != ";" && !Current().end) {
            const std::string& text = Current().text;
            const bool identifier = !text.empty() &&
                (std::isalpha(static_cast<unsigned char>(text.front())) || text.front() == '_');
            const bool number = !text.empty() && std::isdigit(static_cast<unsigned char>(text.front()));
            const bool operatorToken = text == "<<" || text == "|" || text == "+" || text == "-" ||
                                       text == "*" || text == "/" || text == "(" || text == ")";
            if (!identifier && !number && !operatorToken) {
                Fail("invalid enum expression token '" + text + "'");
            }
            if (hasToken) {
                expression.push_back(' ');
            }
            expression += text;
            hasToken = true;
            ++index_;
        }
        if (!hasToken) {
            Fail("enum expression cannot be empty");
        }
        return expression;
    }

    static void Validate(const Schema& schema) {
        if (schema.module.empty()) {
            throw IdlcError("module name cannot be empty");
        }
        std::set<std::string> names;
        for (const EnumDefinition& definition : schema.enums) {
            if (!names.insert(definition.name).second) {
                throw IdlcError("duplicate top-level declaration '" + definition.name + "'");
            }
            if (definition.backend != "both" && definition.backend != "cpp" && definition.backend != "glsl") {
                throw IdlcError("enum '" + definition.name + "' uses unsupported backend '" + definition.backend + "'");
            }
            if (definition.underlyingType != "uint32") {
                throw IdlcError("enum '" + definition.name + "' must use uint32 as its underlying type");
            }
        }
        for (const StructDefinition& definition : schema.structs) {
            if (!names.insert(definition.name).second) {
                throw IdlcError("duplicate top-level declaration '" + definition.name + "'");
            }
            if (definition.layout != "std430" && definition.layout != "cpp" && definition.layout != "glsl") {
                throw IdlcError("struct '" + definition.name + "' uses unsupported layout '" + definition.layout + "'");
            }
            for (const FieldDefinition& field : definition.fields) {
                if (field.type != "uint32" && field.type != "int32" &&
                    field.type != "uint64" && field.type != "float32" && field.type != "vec4") {
                    throw IdlcError("struct '" + definition.name + "' uses unsupported field type '" + field.type + "'");
                }
            }
        }
    }

    [[noreturn]] void Fail(const std::string& message) const {
        const Token& token = Current();
        throw IdlcError("line " + std::to_string(token.line) + ", column " +
                        std::to_string(token.column) + ": " + message);
    }

    std::vector<Token> tokens_;
    std::size_t index_ = 0;
};

struct TypeInfo {
    std::string cppType;
    std::string glslType;
    std::size_t size = 0;
    std::size_t alignment = 0;
    std::size_t cppArrayLength = 0;
};

TypeInfo GetTypeInfo(const std::string& type) {
    if (type == "uint32") return {"uint32_t", "uint", 4, 4, 0};
    if (type == "int32") return {"int32_t", "int", 4, 4, 0};
    if (type == "uint64") return {"uint64_t", "uint64_t", 8, 8, 0};
    if (type == "float32") return {"float", "float", 4, 4, 0};
    if (type == "vec4") return {"float", "vec4", 16, 16, 4};
    throw IdlcError("unsupported type '" + type + "'");
}

std::size_t AlignUp(std::size_t value, std::size_t alignment) {
    if (alignment == 0 || (alignment & (alignment - 1)) != 0) {
        throw IdlcError("invalid alignment");
    }
    const std::size_t remainder = value % alignment;
    return remainder == 0 ? value : value + alignment - remainder;
}

struct LaidOutField {
    const FieldDefinition* definition = nullptr;
    TypeInfo type;
    std::size_t offset = 0;
    std::size_t size = 0;
};

struct LaidOutStruct {
    const StructDefinition* definition = nullptr;
    std::vector<LaidOutField> fields;
    std::size_t alignment = 1;
    std::size_t size = 0;
};

LaidOutStruct LayoutStruct(const StructDefinition& definition) {
    LaidOutStruct result;
    result.definition = &definition;
    std::size_t offset = 0;
    for (const FieldDefinition& field : definition.fields) {
        const TypeInfo type = GetTypeInfo(field.type);
        const std::size_t fieldSize = type.size * field.arrayCount;
        offset = AlignUp(offset, type.alignment);
        result.fields.push_back({&field, type, offset, fieldSize});
        offset += fieldSize;
        result.alignment = std::max(result.alignment, type.alignment);
    }
    result.size = AlignUp(offset, result.alignment);
    return result;
}

std::string CppFieldDeclaration(const LaidOutField& field) {
    if (field.type.cppArrayLength == 0 && field.definition->arrayCount == 1) {
        return "    " + field.type.cppType + " " + field.definition->name + ";";
    }
    if (field.type.cppArrayLength != 0) {
        if (field.definition->arrayCount == 1) {
            return "    " + field.type.cppType + " " + field.definition->name + "[" +
                   std::to_string(field.type.cppArrayLength) + "];";
        }
        return "    " + field.type.cppType + " " + field.definition->name + "[" +
               std::to_string(field.definition->arrayCount) + "][" +
               std::to_string(field.type.cppArrayLength) + "];";
    }
    return "    " + field.type.cppType + " " + field.definition->name + "[" +
           std::to_string(field.definition->arrayCount) + "];";
}

std::string GlslFieldDeclaration(const LaidOutField& field) {
    const std::string type = field.type.glslType;
    if (field.definition->arrayCount == 1) {
        return "    " + type + " " + field.definition->name + ";";
    }
    return "    " + type + " " + field.definition->name + "[" +
           std::to_string(field.definition->arrayCount) + "];";
}

std::string GenerateCpp(const Schema& schema) {
    std::ostringstream output;
    output << "#pragma once\n";
    output << "#include <cstddef>\n";
    output << "#include <cstdint>\n\n";
    for (const EnumDefinition& definition : schema.enums) {
        if (definition.backend == "glsl") {
            continue;
        }
        output << "enum " << definition.name << " : uint32_t {\n";
        for (const EnumValue& value : definition.values) {
            output << "    " << value.name << " = " << value.expression << ",\n";
        }
        output << "};\n\n";
    }
    for (const StructDefinition& definition : schema.structs) {
        if (definition.layout == "glsl") {
            continue;
        }
        const LaidOutStruct layout = LayoutStruct(definition);
        output << "struct " << definition.name << " {\n";
        for (const LaidOutField& field : layout.fields) {
            output << CppFieldDeclaration(field) << "\n";
        }
        output << "};\n";
        output << "static_assert(sizeof(" << definition.name << ") == " << layout.size
               << ", \"N4DC IDL layout mismatch: " << definition.name << "\");\n";
        for (const LaidOutField& field : layout.fields) {
            output << "static_assert(offsetof(" << definition.name << ", " << field.definition->name
                   << ") == " << field.offset << ", \"N4DC IDL offset mismatch: "
                   << definition.name << "." << field.definition->name << "\");\n";
        }
        output << "\n";
    }
    return output.str();
}

std::string GenerateGlsl(const Schema& schema) {
    std::ostringstream output;
    output << "#ifndef N4DC_GPU_TYPES_GLSL\n";
    output << "#define N4DC_GPU_TYPES_GLSL\n\n";
    for (const EnumDefinition& definition : schema.enums) {
        if (definition.backend == "cpp") {
            continue;
        }
        for (const EnumValue& value : definition.values) {
            output << "const uint " << value.name << " = " << value.expression << ";\n";
        }
        output << "\n";
    }
    for (const StructDefinition& definition : schema.structs) {
        if (definition.layout == "cpp") {
            continue;
        }
        const LaidOutStruct layout = LayoutStruct(definition);
        output << "struct " << definition.name << " {\n";
        for (const LaidOutField& field : layout.fields) {
            output << GlslFieldDeclaration(field) << "\n";
        }
        output << "};\n\n";
    }
    output << "#endif\n";
    return output.str();
}

void WriteTextFile(const std::filesystem::path& path, const std::string& content) {
    std::error_code error;
    if (!path.parent_path().empty()) {
        std::filesystem::create_directories(path.parent_path(), error);
        if (error) {
            throw IdlcError("cannot create output directory '" + path.parent_path().string() +
                            "': " + error.message());
        }
    }
    std::ofstream stream(path, std::ios::binary | std::ios::trunc);
    if (!stream) {
        throw IdlcError("cannot open output '" + path.string() + "'");
    }
    stream.write(content.data(), static_cast<std::streamsize>(content.size()));
    if (!stream) {
        throw IdlcError("cannot write output '" + path.string() + "'");
    }
}

std::string ReadTextFile(const std::filesystem::path& path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) {
        throw IdlcError("cannot open input '" + path.string() + "'");
    }
    std::ostringstream contents;
    contents << stream.rdbuf();
    if (!stream.good() && !stream.eof()) {
        throw IdlcError("cannot read input '" + path.string() + "'");
    }
    return contents.str();
}

struct Options {
    std::filesystem::path input;
    std::filesystem::path cppOutput;
    std::filesystem::path glslOutput;
    std::filesystem::path stamp;
    bool help = false;
};

Options ParseOptions(int argc, char** argv) {
    Options options;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        auto consume = [&](const std::string& name) -> std::filesystem::path {
            if (index + 1 >= argc) {
                throw IdlcError("missing value for " + name);
            }
            return argv[++index];
        };
        if (argument == "--input") {
            options.input = consume(argument);
        } else if (argument == "--cpp-output") {
            options.cppOutput = consume(argument);
        } else if (argument == "--glsl-output") {
            options.glslOutput = consume(argument);
        } else if (argument == "--stamp") {
            options.stamp = consume(argument);
        } else if (argument == "--help") {
            options.help = true;
            std::cout << "idlc --input <file> --cpp-output <file> --glsl-output <file> [--stamp <file>]\n";
            return options;
        } else {
            throw IdlcError("unknown argument '" + argument + "'");
        }
    }
    if (options.input.empty() || options.cppOutput.empty() || options.glslOutput.empty()) {
        throw IdlcError("input, cpp-output, and glsl-output are required");
    }
    return options;
}

} 

int main(int argc, char** argv) {
    try {
        const Options options = ParseOptions(argc, argv);
        if (options.help) {
            return 0;
        }
        const std::string source = ReadTextFile(options.input);
        const Schema schema = Parser(Lexer(source).Lex()).Parse();
        WriteTextFile(options.cppOutput, GenerateCpp(schema));
        WriteTextFile(options.glslOutput, GenerateGlsl(schema));
        if (!options.stamp.empty()) {
            WriteTextFile(options.stamp, "N4DC IDL outputs are current\n");
        }
        return 0;
    } catch (const IdlcError& error) {
        std::cerr << "idlc: error: " << error.what() << "\n";
        return 1;
    } catch (const std::exception& error) {
        std::cerr << "idlc: unexpected error: " << error.what() << "\n";
        return 1;
    }
}
