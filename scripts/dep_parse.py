#!/usr/bin/env python3

import sys, re, os
from pathlib import Path

class _DiGraph:
    # modelled after networkx
    nodes = {}
    edges = []

    def add_node(self, node, **kwargs):
        self.nodes[node] = kwargs

    def remove_node(self, node):
        self.nodes.pop(node, None)
        self.edges = [
            (n_from, n_to) for (n_from, n_to) in self.edges
            if n_from != node and n_to != node
        ]

    def add_edge(self, node_from, node_to):
        for node in [node_from, node_to]:
            if not node in self.nodes:
                self.add_node(node)
        self.edges.append((node_from, node_to))

    def copy(self):
        return self.nodes.copy()
    
    def out_edges(self, node):
        return [(n_from, n_to) for (n_from, n_to) in self.edges if n_from == node]


class VHDLDependencyParser:
    TESTBENCH_FILE_REGEX = r"(_[tT][bB]\.)|(\/[tT][bB]_)"

    PACKAGE_DEF_REGEX = [
        r"package\s+(?P<name>[\w\d]+)\s+is"
    ]
    PACKAGE_BODY_DEF_REGEX = [
        r"package\s+body\s+(?P<name>[\w\d]+)\s+is"
    ]
    ENTITY_DEF_REGEX = [
        r"entity\s+(?P<name>[\w\d]+)\s+is"
    ]
    ARCH_DEF_REGEX = [
        r"architecture\s+(?P<name>[\w\d]+)\s+of\s+(?P<entity>[\w\d]+)\s+is"
    ]

    PACKAGE_USE_REGEX = [
        r"use\s+(?P<library>[\w\d]+)\.(?P<name>[\w\d]+)\."
    ]
    ENTITY_USE_REGEX = [
        r"entity\s+(?P<library>[\w\d]+)\.(?P<name>[\w\d]+)\s(?P<architecture>)", # unspecified architecture
        r"entity\s+(?P<library>[\w\d]+)\.(?P<name>[\w\d]+)\((?P<architecture>[\w\d]+)\)\s", # specified architecture
        r"component\s+(?P<name>[\w\d]+)\s+is(?P<library>)(?P<architecture>)" # unspecified library & achitecture
    ]

    PSL_REGEX = [
        # psl vunits are special, they are definition and use in the same line
        r"vunit\s+(?P<name>[\w\d]+)\((?P<entity>[\w\d]+)\((?P<architecture>[\w\d]+)\)\)\s",
        r"vunit\s+(?P<name>[\w\d]+)\((?P<entity>[\w\d]+)(?P<architecture>)\)\s" # unspecified architecture
    ]

    def __init__(self):
        self._dep_graph = _DiGraph()

    def glob_parse(self, path, library="work", ignore=None):
        if isinstance(path, str):
            path = Path(path)
        base_path = path.resolve()
        ignored_files = [Path(i).resolve() for i in ignore]
        patterns = ["**/*.vhd*", "**/*.psl"]
        for pattern in patterns:
            for file in base_path.glob(pattern):
                if file not in ignored_files:
                    vhdl_parser.parse(file, library)

    def parse(self, file, library="work"):
        if isinstance(file, str):
            file = Path(file)
        filepath = file.resolve()
        # parse all files for what design units it provides and what it uses
        provides, uses = self._parse_file(filepath, library)
        # add to dependency graph
        for provide in provides:
            p = provide.lower()
            self._dep_graph.add_node(p, file=filepath)
            for use in uses:
                u = use.lower()
                if p == u: continue
                self._dep_graph.add_edge(p, u)
            # For any first-level design units (packages and entities) add a
            # general */ANY node. This resolves to all second level units
            # (package bodies and architectures) once resolve() is called.
            if p.count(".") == 1:
                self._dep_graph.add_node(p + ".*")

    def resolve(self):
        # resolve unconstrained / generic entity uses
        g = self._dep_graph.copy()
        for u in g:
            for v in g:
                if self._is_refering_to(u, v):
                    self._dep_graph.add_edge(u, v)

    def remove(self, units=["ieee", "std"]):
        # Remove units like ieee.std_logic_1164 or ieee.math_real which are
        # assumed to be always available by the tools.
        g = self._dep_graph.copy()
        for n in g:
            if any([n.startswith(unit + ".") for unit in units]):
                self._dep_graph.remove_node(n)

    def write_makefile_rules(self):
        for n in self._dep_graph.nodes:
            node = self._dep_graph.nodes[n]
            # name of the design unit (entity, architecture, package, etc.)
            design_unit = n.replace("*", "ANY") # make does not like "*"
            # file that defines the design unit, only if not a */ANY unit
            obj_file = ""
            if "file" in node:
                file = node["file"]
                root = Path("..").resolve() # assumes we are in $(root)/scripts
                obj_file = "obj/" + str(file.relative_to(root)) + ".o"
            # ignore referenced design units that we do not know a file for
            if not "ANY" in design_unit and not obj_file:
                print(f"Referenced design unit '{design_unit}' is not defined in any file. Ignoring.", file=sys.stderr)
                continue
            # print design unit object dependencies
            # <design_unit>: <object_file_dependencies>
            #     @touch <design_unit>
            print(f"du/{design_unit}: {obj_file}")
            print(f"\t@echo [DU] {design_unit}")
            print("\t@mkdir -p $(@D)")
            print("\t@touch $@")
            # print obj file dependency-only rule
            # <obj_file>: <design_unit_dependencies>
            if obj_file:
                print(f"{obj_file}:", end=" ")
                for (_, du_dep) in self._dep_graph.out_edges(n):
                    node_dep = self._dep_graph.nodes[du_dep]
                    # If dependency (e.g. entity and architecture) are in the
                    # same file, then ignore it, compiling the file will resolve
                    # it. If not done then make warns about circular rules.
                    if node.get("file") != node_dep.get("file"):
                        print("du/" + du_dep.replace("*", "ANY"), end=" ")
                print("")
                # add testbenches to OBJS_TB, other sources to OBJS
                if re.search(self.TESTBENCH_FILE_REGEX, obj_file, re.IGNORECASE):
                    print(f"OBJS_TB += {obj_file}")
                else:
                    print(f"OBJS += {obj_file}")

    def _parse_file(self, filepath, library="work"):
        with open(filepath, mode="r", encoding="utf-8") as file:
            source = file.read()
            defines = self._parse_src_to_defines(source, library)
            uses = self._parse_src_to_uses(source)
            comb_define, comb_use = self._parse_src_to_defines_and_uses(source, library)
            defines.update(comb_define)
            uses.update(comb_use)
        return defines, uses

    def _parse_src_to_defines(self, src, library):
        defines = set()
        # defining any package?
        for regex in self.PACKAGE_DEF_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                defines.add(f"{library}.{match.group('name')}")
        # defining any entity?
        for regex in self.ENTITY_DEF_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                defines.add(f"{library}.{match.group('name')}")
        return defines

    def _parse_src_to_uses(self, src):
        uses = set()
        # using any library package?
        for regex in self.PACKAGE_USE_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                uses.add(f"{match.group('library')}.{match.group('name')}")
        # using any entities?
        for regex in self.ENTITY_USE_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                arch = match.group('architecture')
                if arch:
                    uses.add(f"{match.group('library') or '*'}.{match.group('name')}.{arch}")
                else:
                    uses.add(f"{match.group('library') or '*'}.{match.group('name')}")
        return uses

    def _parse_src_to_defines_and_uses(self, src, library):
        defines = set()
        uses = set()
        # defining any package body?
        for regex in self.PACKAGE_BODY_DEF_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                defines.add(f"{library}.{match.group('name')}.body")
                uses.add(f"{library}.{match.group('name')}")
        # defining any architecture?
        for regex in self.ARCH_DEF_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                defines.add(f"{library}.{match.group('entity')}.{match.group('name')}")
                uses.add(f"{library}.{match.group('entity')}")
        # defining a PSL vunit for an entity?
        for regex in self.PSL_REGEX:
            for match in re.finditer(regex, src, re.IGNORECASE):
                defines.add(f"{library}.{match.group('entity')}.{match.group('architecture') or '*'}.{match.group('name')}")
                uses.add(f"*.{match.group('entity')}.{match.group('architecture') or '*'}")
        return (defines, uses)

    def _is_refering_to(self, u, v):
        if "*" in u and not "*" in v:
            # convert to regex pattern
            pattern = u.replace(".", "\.").replace("*", ".+")
            match = re.search(pattern, v, re.IGNORECASE)
            if match:
                return True
        return False


if __name__ == "__main__":
    print("Scanning dependencies...", file=sys.stderr)

    vhdl_parser = VHDLDependencyParser()

    # Call this script with these environment variables set:
    #  - LIBS:          space separated list of library names
    #  - LIB_PATHS:     space separated list of corresponding library paths
    #  - IGNORED_FILES: space separated list of files or file patterns to ignore

    libs   = os.getenv("LIBS", "").split()
    paths  = os.getenv("LIB_PATHS", "").split()
    ignore = os.getenv("IGNORED_FILES", "").split()
    lib_count = len(libs)

    # for debugging
    base_path = str(Path(__file__).parent)
    if not lib_count > 0: libs = ["work", "neorv32"]
    if not lib_count > 0: paths = [base_path + "/../vhdl", base_path + "/../lib/neorv32"]
    if not lib_count > 0: ignore = [base_path + "/../lib/neorv32/rtl/core/neorv32_icache.vhd"]

    for lib, path in zip(libs, paths):
        vhdl_parser.glob_parse(path, library=lib, ignore=ignore)

    vhdl_parser.remove(["ieee", "std"])
    vhdl_parser.resolve()

    vhdl_parser.write_makefile_rules()
