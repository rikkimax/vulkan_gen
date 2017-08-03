import std.stdio;
import std.experimental.xml;
import std.experimental.xml.dom;

struct Context {
	Handle[] handles;
	FunctionPointer[] functionPointers;
}

struct Handle {
	string name;
	bool force64Bit;
}

struct FunctionPointer {
	string name;
	string returnType;
	FunctionArgument[] args;
}

struct FunctionArgument {
	string name;
	string type;
}

Context context;

void main() {
	import std.file : readText;
	import std.string : strip;

	string raw_input = readText("Vulkan-Docs/src/spec/vk.xml");

	auto domBuilder = raw_input
		.lexer
		.parser
		.cursor((CursorError err){})
		.domBuilder;
	domBuilder.setSource(raw_input);
	domBuilder.buildRecursive;
	auto dom = domBuilder.getDocument;

	auto allTypes = dom.getElementsByTagName("types");

	foreach(types; allTypes) {
	F_Types_2: foreach(type; types.childNodes()) {
			Node!string category;

			if (type.attributes !is null)
				category = type.attributes.getNamedItem("category");
			if (category is null)
				continue F_Types_2;
			else {
				switch(category.nodeValue) {
					case "include":
					case "define":
					case "bitmask":
					case "basetype":
					case "enum":
						continue F_Types_2;

					case "handle":
						auto handleType = type.firstChild.firstChild;
						if (handleType is null)
							continue F_Types_2;

						if (handleType.nodeValue == "VK_DEFINE_HANDLE") {
							context.handles ~= Handle(type.lastChild.previousSibling.firstChild.nodeValue, false);
						} else if (handleType.nodeValue == "VK_DEFINE_NON_DISPATCHABLE_HANDLE") {
							context.handles ~= Handle(type.lastChild.previousSibling.firstChild.nodeValue, true);
						}

						break;

					case "funcpointer":
						//typedef <return> (VKAPI_PTR *
						//name <name>
						// )(
						//... type <type> [*]

						uint stage;
						FunctionPointer fp;

						bool lastConst;

						foreach(cn; type.childNodes()) {
							switch(stage) {
								case 0:
									fp.returnType = cn.textContent[8..$-13];
									stage++;
									break;
								case 1:
									fp.name = cn.textContent;
									stage++;
									break;
								case 2:
									stage++;
									break;

								default:
									stage++;

									if (stage % 2 == 0) {
										//type

										if (lastConst) {
											fp.args ~= FunctionArgument(null, "const(" ~ cn.textContent ~ ")");
											lastConst = false;
										} else {
											fp.args ~= FunctionArgument(null, cn.textContent);
										}
									} else {
										//name

										auto last = &fp.args[$-1];

										if (cn.textContent[0] == '*') {
											last.type ~= '*';
											last.name = cn.textContent[1 .. $].strip;
										} else {
											last.name = cn.textContent.strip;
										}

										if (last.name.length > 5 && last.name[$-5..$] == "const") {
											lastConst = true;
											last.name = last.name[0 .. $-5].strip;
										}

										if (last.name[$-1] == ',')
											last.name = last.name[0 .. $-1];
										if (last.name[$-2 .. $] == ");")
											last.name = last.name[0 .. $-2];
									}
									break;
							}
						}

						context.functionPointers ~= fp;
						break;

					default:
						writeln("\t category: ", category.nodeValue);
						continue F_Types_2;
				}
			}
		}
	}


	writeln("===================");

	writeln("Handles:");
	foreach(handle; context.handles) {
		writeln("\t- ", handle.name, handle.force64Bit ? " [64]" : " [void*]");
	}
	writeln();

	writeln("Function pointers:");
	foreach(fp; context.functionPointers) {
		write("\t- ", fp.returnType, " ", fp.name, "(");

		foreach(i, arg; fp.args)
			write(i > 0 ? ", " : "", arg.type, " ", arg.name);
		writeln(")");
	}
}
