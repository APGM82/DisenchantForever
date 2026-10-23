#!/usr/bin/env python3
"""Regenera NoDisenchant.lua y OwnLoot.lua con las tablas del cliente (wago.tools).

  python3 herramientas/actualizar_datos.py              # build instalada (.build.info)
  python3 herramientas/actualizar_datos.py 1.60.1.70425

Hacerlo tras cada parche:
  * NoDisenchant.lua: armas y armaduras verdes, azules y moradas con el flag ITEM_FLAG_NO_DISENCHANT
    (0x8000 en Flags_0 de ItemSparse). La API del juego no lo da y el addon no puede saberlo de otra forma.
  * OwnLoot.lua: objetos verdes, azules y morados de cualquier clase con ITEM_FLAG2_DISENCHANT_TO_LOOT_TABLE
    (0x40000000 en Flags_1): se desencantan en un botin propio, como las efigies de cera de la mision de
    encantamiento de la Torre de Azora. Tampoco lo da la API.
  * Avisa si han cambiado los tramos de ItemDisenchantLoot; entonces hay que revisar Materials.lua a mano
    y guardar la tabla nueva en herramientas/ItemDisenchantLoot.csv.
"""

import csv
import io
import os
import sys
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(AQUI, "..", "DisenchantForever")
WOW = os.path.expanduser("~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft")
URL = "https://wago.tools/db2/{tabla}/csv?build={build}"

NO_DISENCHANT = 0x8000
BOTIN_PROPIO = 0x40000000
ARMA, ARMADURA = 2, 4


def build_instalada():
    with open(os.path.join(WOW, ".build.info"), encoding="utf-8") as f:
        filas = list(csv.reader(f, delimiter="|"))
    columnas = [c.split("!")[0] for c in filas[0]]
    versiones = [dict(zip(columnas, fila)).get("Version", "") for fila in filas[1:]]
    forever = [v for v in versiones if v.startswith("1.")]
    if not forever:
        sys.exit("no encuentro la build de Forever en .build.info; pasala a mano")
    return max(forever, key=lambda v: [int(x) for x in v.split(".")])


def tabla(nombre, build):
    # sin un User-Agent propio wago.tools responde 403
    peticion = urllib.request.Request(URL.format(tabla=nombre, build=build),
                                      headers={"User-Agent": "disenchant-forever/1.0"})
    with urllib.request.urlopen(peticion, timeout=300) as r:
        texto = r.read().decode("utf-8-sig")
    filas = list(csv.DictReader(io.StringIO(texto)))
    if not filas:
        sys.exit(f"wago.tools no tiene {nombre} para la build {build}")
    return filas


def escribir_lista(archivo, tabla_lua, ids, build, descripcion):
    lineas = [", ".join(str(i) for i in ids[n:n + 12]) + "," for n in range(0, len(ids), 12)]
    with open(os.path.join(ADDON, archivo), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"-- {descripcion}\n")
        f.write(f"-- Generado por herramientas/actualizar_datos.py con la build {build}: no tocar a mano.\n\n")
        f.write(f"local _, ns = ...\n\nns.{tabla_lua} = {{}}\n\nfor _, itemID in ipairs({{\n")
        f.writelines(f"    {linea}\n" for linea in lineas)
        f.write(f"}}) do\n    ns.{tabla_lua}[itemID] = true\nend\n")
    print(f"{archivo}: {len(ids)} objetos")


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else build_instalada()
    print(f"build {build}")

    clases = {fila["ID"]: int(fila["ClassID"]) for fila in tabla("Item", build)}
    ids, propios = [], []
    for fila in tabla("ItemSparse", build):
        if not 2 <= int(fila["OverallQualityID"]) <= 4:
            continue
        if int(fila["Flags_1"]) & BOTIN_PROPIO and not int(fila["Flags_0"]) & NO_DISENCHANT:
            propios.append(int(fila["ID"]))
        if clases.get(fila["ID"]) not in (ARMA, ARMADURA):
            continue
        if int(fila["Flags_0"]) & NO_DISENCHANT:
            ids.append(int(fila["ID"]))
    ids.sort()
    propios.sort()

    escribir_lista("NoDisenchant.lua", "noDisenchant", ids, build,
                   "Armas y armaduras que el juego no deja desencantar (flag 0x8000 de ItemSparse).")
    escribir_lista("OwnLoot.lua", "ownLoot", propios, build,
                   "Objetos que se desencantan en un botin propio y no en los materiales de siempre\n"
                   "-- (flag 0x40000000 de Flags_1 en ItemSparse), sean de la clase que sean.")

    guardada = os.path.join(AQUI, "ItemDisenchantLoot.csv")
    clave = ("Class", "Quality", "MinLevel", "MaxLevel")
    nueva = sorted(tuple(int(fila[c]) for c in clave) for fila in tabla("ItemDisenchantLoot", build))
    if os.path.exists(guardada):
        with open(guardada, encoding="utf-8") as f:
            vieja = sorted(tuple(int(fila[c]) for c in clave) for fila in csv.DictReader(f))
        if nueva != vieja:
            print("OJO: han cambiado los tramos de ItemDisenchantLoot. Revisa Materials.lua y vuelve a guardar")
            print("     la tabla en herramientas/ItemDisenchantLoot.csv.")
            for t in sorted(set(vieja) - set(nueva)):
                print("     quitado:", dict(zip(clave, t)))
            for t in sorted(set(nueva) - set(vieja)):
                print("     nuevo:  ", dict(zip(clave, t)))
            sys.exit(1)
        print("tramos de ItemDisenchantLoot: sin cambios")
    else:
        with open(guardada, "w", encoding="utf-8", newline="\n") as f:
            f.write(",".join(clave) + "\n")
            f.writelines(",".join(str(x) for x in t) + "\n" for t in nueva)
        print(f"tramos guardados en {os.path.relpath(guardada)}")


if __name__ == "__main__":
    main()
