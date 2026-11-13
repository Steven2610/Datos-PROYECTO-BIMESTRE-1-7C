"""
Genera rdf/catalogos.ttl (valores SKOS de los catálogos) y
rdf/ejemplo_instancias.ttl (1 accidente con sus personas, solo ilustrativo)
a partir de los CSV limpios producidos por scripts/etl_chicago.R.

Uso:
    python scripts/generar_catalogos.py <crashes_limpio.csv> <people_limpio.csv> <carpeta_rdf>
"""
import re
import sys

import pandas as pd

PREFIJOS = """@prefix vial:   <http://example.org/vialchicago#> .
@prefix rec:    <http://example.org/vialchicago/recurso/> .
@prefix rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xsd:    <http://www.w3.org/2001/XMLSchema#> .
@prefix skos:   <http://www.w3.org/2004/02/skos/core#> .
@prefix schema: <https://schema.org/> .
@prefix geo:    <http://www.opengis.net/ont/geosparql#> .
"""


def slug(texto: str) -> str:
    """'SIDESWIPE SAME DIRECTION' -> 'SideswipeSameDirection'"""
    partes = re.split(r"[^A-Za-z0-9]+", texto)
    return "".join(p.capitalize() for p in partes if p)


def esc(texto: str) -> str:
    return texto.replace("\\", "\\\\").replace('"', '\\"')


def catalogos(c, p):
    defs = [
        ("TipoPrimerImpacto", "EsquemaTipoPrimerImpacto", "impacto", c["FIRST_CRASH_TYPE"]),
        ("TipoUsuario", "EsquemaTipoUsuario", "usuario", p["PERSON_TYPE"]),
        ("ClasificacionLesion", "EsquemaClasificacionLesion", "lesion", p["INJURY_CLASSIFICATION"]),
    ]
    out = ["# Valores de catálogo generados desde los datos limpios (scripts/generar_catalogos.py)",
           PREFIJOS]
    for clase, esquema, pref, serie in defs:
        out.append(f"\n# ---- vial:{clase} ----")
        for valor, n in serie.value_counts().items():
            out.append(
                f'rec:{pref}_{slug(valor)} a vial:{clase} ;\n'
                f'    skos:inScheme vial:{esquema} ;\n'
                f'    skos:prefLabel "{esc(valor)}"@en .   # {n} registros'
            )
    return "\n".join(out) + "\n"


def ejemplo(c, p):
    # accidente reciente con 2+ personas para ilustrar la relación 1:N
    n = p.groupby("CRASH_RECORD_ID").size()
    cid = next(i for i in c["CRASH_RECORD_ID"] if n.get(i, 0) >= 2)
    a = c[c["CRASH_RECORD_ID"] == cid].iloc[0]
    personas = p[p["CRASH_RECORD_ID"] == cid]
    corto = cid[:12]
    out = ["# Ejemplo ILUSTRATIVO de instancias (la generación masiva corresponde a 1C)",
           PREFIJOS,
           f"rec:zona_{a.BEAT_OF_OCCURRENCE} a vial:ZonaPolicial ;\n"
           f'    vial:codigoZona "{a.BEAT_OF_OCCURRENCE}" .\n',
           f"rec:accidente_{corto} a vial:Accidente ;\n"
           f'    vial:idAccidente "{cid}" ;\n'
           f'    vial:fechaHora "{a.CRASH_DATE.replace("Z", "")}"^^xsd:dateTime ;\n'
           f'    vial:nombreCalle "{esc(a.STREET_NAME)}" ;\n'
           f"    vial:ocurreEnZona rec:zona_{a.BEAT_OF_OCCURRENCE} ;\n"
           f"    vial:tipoPrimerImpacto rec:impacto_{slug(a.FIRST_CRASH_TYPE)} ;\n"
           f"    geo:hasGeometry rec:geom_{corto} ;\n"
           "    vial:involucraPersona " + " , ".join(f"rec:persona_{x}" for x in personas.PERSON_ID) + " .\n",
           f"rec:geom_{corto} a geo:Geometry ;\n"
           f'    geo:asWKT "POINT({a.LONGITUDE} {a.LATITUDE})"^^geo:wktLiteral .\n']
    for _, r in personas.iterrows():
        out.append(
            f"rec:persona_{r.PERSON_ID} a vial:Persona ;\n"
            f'    vial:idPersona "{r.PERSON_ID}" ;\n'
            f"    vial:edad {int(r.AGE)} ;\n"
            f'    schema:gender "{r.SEX}" ;\n'
            f"    vial:participaEn rec:accidente_{corto} ;\n"
            f"    vial:tipoUsuario rec:usuario_{slug(r.PERSON_TYPE)} ;\n"
            f"    vial:clasificacionLesion rec:lesion_{slug(r.INJURY_CLASSIFICATION)} .\n"
        )
    return "\n".join(out)


if __name__ == "__main__":
    ruta_c, ruta_p, carpeta = sys.argv[1:4]
    c = pd.read_csv(ruta_c, dtype=str)
    p = pd.read_csv(ruta_p, dtype=str)
    with open(f"{carpeta}/catalogos.ttl", "w", encoding="utf-8") as f:
        f.write(catalogos(c, p))
    with open(f"{carpeta}/ejemplo_instancias.ttl", "w", encoding="utf-8") as f:
        f.write(ejemplo(c, p))
    print("Listo:", carpeta)
