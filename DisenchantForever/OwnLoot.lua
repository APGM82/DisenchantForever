-- Objetos que se desencantan en un botin propio y no en los materiales de siempre
-- (flag 0x40000000 de Flags_1 en ItemSparse), sean de la clase que sean.
-- Generado por herramientas/actualizar_datos.py con la build 1.60.1.70532: no tocar a mano.

local _, ns = ...

ns.ownLoot = {}

for _, itemID in ipairs({
    242266, 242267, 242268, 242363, 247883, 273878, 274027, 275724, 276538, 276539, 276540, 276541,
    279246, 279247, 279248, 279249, 279250, 279251, 279252, 279253, 279254, 279255, 279256, 279257,
    279258, 279259, 279260, 279261, 279262, 279263, 279264, 279265, 279266, 279267, 279268, 279269,
    279270, 279271,
}) do
    ns.ownLoot[itemID] = true
end
