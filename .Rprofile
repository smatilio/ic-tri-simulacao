# Pacotes do renv ficam fora do OneDrive, em %LOCALAPPDATA%\R\renv\library
# (precisa vir antes do activate.R)
if (.Platform$OS.type == "windows" && nzchar(Sys.getenv("LOCALAPPDATA"))) {
  Sys.setenv(RENV_PATHS_LIBRARY_ROOT = file.path(Sys.getenv("LOCALAPPDATA"), "R", "renv", "library"))
}

source("renv/activate.R")
