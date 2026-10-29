# Biblioteca de pacotes do renv fora da pasta do projeto: no Windows ela fica em
# %LOCALAPPDATA%\R\renv\library, para que servicos de sincronizacao (OneDrive,
# Dropbox) nao copiem centenas de MB de pacotes. Precisa vir antes do activate.R.
if (.Platform$OS.type == "windows" && nzchar(Sys.getenv("LOCALAPPDATA"))) {
  Sys.setenv(RENV_PATHS_LIBRARY_ROOT = file.path(Sys.getenv("LOCALAPPDATA"), "R", "renv", "library"))
}

source("renv/activate.R")
