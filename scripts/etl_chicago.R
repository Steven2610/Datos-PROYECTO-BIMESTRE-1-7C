# =====================================================================
# ETL - Práctica 1B (3.1): Crashes + People, Chicago
#
# Produce 3 CSV:
#   1. crashes_limpio.csv        accidentes sin nulos ni duplicados
#   2. people_limpio.csv         personas   sin nulos ni duplicados
#   3. crashes_people_unido.csv  una fila por persona + datos de su accidente
#
# Reglas:
#   - Solo las columnas elegidas.
#   - Sin duplicados (por clave) y sin ningún valor nulo en esas columnas.
#   - Solo registros con relación: cada persona tiene su accidente y cada
#     accidente tiene al menos una persona.
#   - Tope de 600 000 registros por archivo (muestra). Se conservan los
#     accidentes MÁS RECIENTES con TODAS sus personas, para no cortar accidentes.
#
# Requiere: install.packages(c("data.table", "lubridate"))
# =====================================================================
suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

# ---------------------------- PARÁMETROS -----------------------------
descargas    <- file.path(Sys.getenv("USERPROFILE"), "Downloads")
RUTA_CRASHES <- file.path(descargas, "Traffic_Crashes_-_Crashes_20261112.csv")
RUTA_PEOPLE  <- file.path(descargas, "Traffic_Crashes_-_People_20261112.csv")
SALIDA       <- file.path(descargas, "chicago_procesado")   # carpeta de salida
LIMITE       <- 600000                                      # tope por archivo

COLS_CRASHES <- c("CRASH_RECORD_ID", "CRASH_DATE", "BEAT_OF_OCCURRENCE",
                  "LATITUDE", "LONGITUDE", "STREET_NAME", "FIRST_CRASH_TYPE")
COLS_PEOPLE  <- c("PERSON_ID", "CRASH_RECORD_ID", "PERSON_TYPE",
                  "AGE", "SEX", "INJURY_CLASSIFICATION")

dir.create(SALIDA, recursive = TRUE, showWarnings = FALSE)

# ---------------------------- UTILIDADES -----------------------------
calidad <- list()
reg <- function(fuente, metrica, valor) {
  calidad[[length(calidad) + 1]] <<- data.table(fuente = fuente,
                                                metrica = metrica,
                                                valor = as.character(valor))
  message(sprintf("[%s] %s: %s", fuente, metrica, valor))
}

leer <- function(ruta, cols) {
  if (!file.exists(ruta)) stop("No existe el archivo: ", ruta)
  enc  <- names(fread(ruta, nrows = 0))
  norm <- toupper(gsub("[ .]", "_", enc))
  idx  <- match(cols, norm)
  if (anyNA(idx)) stop("Columnas no encontradas: ", paste(cols[is.na(idx)], collapse = ", "))
  dt <- fread(ruta, select = enc[idx], colClasses = "character",
              na.strings = c("", "NA"), showProgress = FALSE)
  setnames(dt, enc[idx], cols)
  dt
}

limpiar_txt <- function(x) {
  x <- toupper(trimws(gsub("\\s+", " ", x)))
  x[!is.na(x) & x == ""] <- NA_character_
  x
}

# ============================== CRASHES ==============================
crashes <- leer(RUTA_CRASHES, COLS_CRASHES)
reg("crashes", "1_filas_archivo_original", nrow(crashes))

reg("crashes", "2_duplicados_por_clave", sum(duplicated(crashes$CRASH_RECORD_ID)))
crashes <- unique(crashes[!is.na(CRASH_RECORD_ID)], by = "CRASH_RECORD_ID")

crashes[, CRASH_DATE := parse_date_time(
  CRASH_DATE, orders = c("mdY IMSp", "mdY HMS", "Ymd HMS", "Ymd"),
  tz = "UTC", quiet = TRUE)]

for (col in c("STREET_NAME", "FIRST_CRASH_TYPE")) {
  set(crashes, j = col, value = limpiar_txt(crashes[[col]]))
}

# Zona (beat) con 4 dígitos
crashes[, BEAT_OF_OCCURRENCE := {
  b <- suppressWarnings(as.integer(BEAT_OF_OCCURRENCE))
  ifelse(is.na(b), NA_character_, sprintf("%04d", b))
}]

# Coordenadas: fuera de Chicago, o en 0 -> se vuelven nulas
crashes[, `:=`(LATITUDE  = suppressWarnings(as.numeric(LATITUDE)),
               LONGITUDE = suppressWarnings(as.numeric(LONGITUDE)))]
ok_geo <- crashes[, !is.na(LATITUDE) & !is.na(LONGITUDE) &
                    LATITUDE >= 41.6 & LATITUDE <= 42.1 &
                    LONGITUDE >= -87.95 & LONGITUDE <= -87.5]
crashes[!ok_geo, `:=`(LATITUDE = NA_real_, LONGITUDE = NA_real_)]

# Nulos por columna (antes de eliminar) -> para el informe
nulos <- crashes[, lapply(.SD, function(x) sum(is.na(x))), .SDcols = COLS_CRASHES]
for (col in COLS_CRASHES) reg("crashes", paste0("3_nulos_", col), nulos[[col]])

crashes <- crashes[complete.cases(crashes)]
reg("crashes", "4_filas_sin_nulos_ni_duplicados", nrow(crashes))

# =============================== PEOPLE ==============================
people <- leer(RUTA_PEOPLE, COLS_PEOPLE)
reg("people", "1_filas_archivo_original", nrow(people))

reg("people", "2_duplicados_por_clave", sum(duplicated(people$PERSON_ID)))
people <- unique(people[!is.na(PERSON_ID)], by = "PERSON_ID")

for (col in c("PERSON_TYPE", "SEX", "INJURY_CLASSIFICATION")) {
  set(people, j = col, value = limpiar_txt(people[[col]]))
}
people[, AGE := suppressWarnings(as.integer(AGE))]
people[!is.na(AGE) & (AGE < 0 | AGE > 110), AGE := NA_integer_]
people[!(SEX %in% c("M", "F", "X")), SEX := NA_character_]

nulos <- people[, lapply(.SD, function(x) sum(is.na(x))), .SDcols = COLS_PEOPLE]
for (col in COLS_PEOPLE) reg("people", paste0("3_nulos_", col), nulos[[col]])

people <- people[complete.cases(people)]
reg("people", "4_filas_sin_nulos_ni_duplicados", nrow(people))

# ============== SOLO REGISTROS CON RELACIÓN + TOPE DE 600 MIL ========
reg("people", "5_sin_accidente_en_crashes_limpio",
    people[, sum(!CRASH_RECORD_ID %in% crashes$CRASH_RECORD_ID)])
people <- people[CRASH_RECORD_ID %in% crashes$CRASH_RECORD_ID]

reg("crashes", "5_sin_personas_en_people_limpio",
    crashes[, sum(!CRASH_RECORD_ID %in% people$CRASH_RECORD_ID)])
crashes <- crashes[CRASH_RECORD_ID %in% people$CRASH_RECORD_ID]

# Muestra: accidentes más recientes con todas sus personas, hasta LIMITE personas.
# (Como cada accidente tiene >= 1 persona, los accidentes quedan siempre <= LIMITE.)
sel <- merge(crashes[, .(CRASH_RECORD_ID, CRASH_DATE)],
             people[, .N, by = CRASH_RECORD_ID], by = "CRASH_RECORD_ID")
setorder(sel, -CRASH_DATE)
sel[, acumulado := cumsum(N)]
sel <- sel[acumulado <= LIMITE]

crashes <- crashes[CRASH_RECORD_ID %in% sel$CRASH_RECORD_ID]
people  <- people[CRASH_RECORD_ID %in% sel$CRASH_RECORD_ID]
setorder(crashes, -CRASH_DATE)

# ============================== VALIDACIÓN ===========================
stopifnot(!anyNA(crashes), !anyNA(people),
          !anyDuplicated(crashes$CRASH_RECORD_ID),
          !anyDuplicated(people$PERSON_ID),
          all(people$CRASH_RECORD_ID %in% crashes$CRASH_RECORD_ID),
          all(crashes$CRASH_RECORD_ID %in% people$CRASH_RECORD_ID),
          nrow(crashes) <= LIMITE, nrow(people) <= LIMITE)

unido <- merge(people, crashes, by = "CRASH_RECORD_ID", all = FALSE)
stopifnot(nrow(unido) == nrow(people))

reg("final", "crashes_filas", nrow(crashes))
reg("final", "people_filas", nrow(people))
reg("final", "union_filas", nrow(unido))
reg("final", "rango_fechas",
    paste(format(min(crashes$CRASH_DATE), "%Y-%m-%d"), "a",
          format(max(crashes$CRASH_DATE), "%Y-%m-%d")))
reg("final", "distribucion_PERSON_TYPE",
    paste(names(table(people$PERSON_TYPE)), table(people$PERSON_TYPE), sep = "=", collapse = "; "))

# =============================== SALIDAS =============================
fwrite(crashes, file.path(SALIDA, "crashes_limpio.csv"))
fwrite(people,  file.path(SALIDA, "people_limpio.csv"))
fwrite(unido,   file.path(SALIDA, "crashes_people_unido.csv"))
fwrite(rbindlist(calidad), file.path(SALIDA, "calidad_etl.csv"))   # conteos para el informe 3.1
message("\nListo. Archivos en: ", SALIDA)



orig <- fread(RUTA_PEOPLE, select = "PERSON_TYPE")
round(prop.table(table(orig$PERSON_TYPE)) * 100, 2)