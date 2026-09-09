import lupa
from typing import Any
from tabulate import tabulate, TableFormat, DataRow
from itertools import zip_longest

lua = lupa.LuaRuntime(unpack_returned_tuples=True)

def dostuff(mod_list: dict[str, Any]):
    format = TableFormat(datarow=DataRow(begin="", sep=" => ", end=""), lineabove=None, linebelowheader=None, linebetweenrows=None,linebelow=None, headerrow=None,padding=0,with_header_hide=None)
    output = ""
    keys = list(sorted(mod_list.keys()))
    # mods that don't seem to have a counterpart
    ignored_mods = ["HandWrapsImplicitLocalBaseEvasionAndEnergyShieldPerLevel", "HandWrapsImplicitLocalBaseEvasionEnergyShieldAndWardPerLevel", "HandWrapsUniqueRecoupLifeEnergyShieldOpenWeakness1"]
    for name in keys:
        if name in ignored_mods:
            continue
        if name.startswith("HandWraps"):
            mod = mod_list[name]
            original_name = name.removeprefix("HandWraps")
            # wtf ggg why do the mods sometimes have underscores
            original_mod = None
            for suffix in ["", "_", "__", "______"]:
                if (original_name + suffix) in mod_list:
                    original_mod = mod_list[original_name + suffix]
            if not original_mod:
                print(name, original_mod)
                exit(1)
            output += f"=== {name.removeprefix("HandWraps")} ===\n"

            original_lines = []

            # ipairs
            i = 1
            while original_mod[i]:
                original_lines.append(original_mod[i])
                i += 1

            new_lines = []
            i = 1
            while mod[i]:
                new_lines.append(mod[i])
                i += 1

            output += tabulate(zip_longest(original_lines, new_lines, fillvalue=""), tablefmt=format)
            output += "\n\n"
    return output

def concat_to_dict(fileName, dest):
    with open(fileName) as f:
        mods = lua.execute(f.read())
    for key in mods.keys():
        dest[key] = mods[key]

def main():
    mods = {}
    concat_to_dict("../src/Data/ModItem.lua", mods)
    concat_to_dict("../src/Data/ModItemExclusive.lua", mods)
    concat_to_dict("../src/Data/ModVeiled.lua", mods)
    print(dostuff(mods))

if __name__ == "__main__":
    main()
