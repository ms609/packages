#!/usr/bin/env Rscript
# Publishes the MaxMin binaries built by .github/workflows/build-maxmin.yml.
#
# Windows/macOS binaries go into the standard drat bin/<os>/contrib/4.6/
# layout, with PACKAGES/.gz/.rds regenerated so normal CRAN-style repo
# resolution finds them. Linux binaries have no such standard path (GitHub
# Pages can't do the UA negotiation P3M uses for Linux binaries), so they're
# published to a stable, unversioned bin/linux/<tag>/MaxMin_latest.tar.gz --
# consumed directly by URL, not through repo resolution.
#
# Run from the repo root with the `artifacts/` directory (from
# actions/download-artifact) present alongside it.

artifacts_dir <- "artifacts"
stopifnot(dir.exists(artifacts_dir))

read_description_field <- function(file, field) {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  if (grepl("\\.zip$", file)) {
    utils::unzip(file, exdir = tmp)
  } else {
    utils::untar(file, exdir = tmp)
  }
  desc_path <- file.path(tmp, "MaxMin", "DESCRIPTION")
  if (!file.exists(desc_path)) {
    stop("DESCRIPTION not found after extracting ", file)
  }
  desc <- read.dcf(desc_path)
  if (!field %in% colnames(desc)) return(NA_character_)
  unname(desc[1, field])
}

artifact_dirs <- list.dirs(artifacts_dir, recursive = FALSE)
manifest <- list()

for (dir in artifact_dirs) {
  name <- basename(dir)
  files <- list.files(dir, full.names = TRUE)
  stopifnot(length(files) == 1)
  file <- files[1]

  # `name` is `maxmin-<os>-r<rversion>`, matching the build workflow's matrix
  # exactly -- kept in lockstep with .github/workflows/build-maxmin.yml.
  is_windows     <- grepl("^maxmin-windows-latest-", name)
  is_macos_arm   <- grepl("^maxmin-macOS-latest-", name)
  is_macos_intel <- grepl("^maxmin-macos-15-intel-", name)
  is_linux_arm_release <- grepl("^maxmin-ubuntu-24\\.04-arm-rrelease$", name)
  is_linux_x86_41      <- grepl("^maxmin-ubuntu-24\\.04-r4\\.1$", name)
  is_linux_arm_devel   <- grepl("^maxmin-ubuntu-24\\.04-arm-rdevel$", name)

  if (is_windows) {
    target_dir <- "bin/windows/contrib/4.6"
    pkg_type <- "win.binary"
    tag <- "windows"
  } else if (is_macos_arm) {
    target_dir <- "bin/macosx/big-sur-arm64/contrib/4.6"
    pkg_type <- "mac.binary"
    tag <- "macos-arm64"
  } else if (is_macos_intel) {
    target_dir <- "bin/macosx/big-sur-x86_64/contrib/4.6"
    pkg_type <- "mac.binary"
    tag <- "macos-x86_64"
  } else if (is_linux_arm_release) {
    target_dir <- "bin/linux/aarch64-release"
    pkg_type <- NA
    tag <- "linux-aarch64-release"
  } else if (is_linux_x86_41) {
    target_dir <- "bin/linux/x86_64-4.1"
    pkg_type <- NA
    tag <- "linux-x86_64-4.1"
  } else if (is_linux_arm_devel) {
    target_dir <- "bin/linux/aarch64-devel"
    pkg_type <- NA
    tag <- "linux-aarch64-devel"
  } else {
    stop("Unrecognised artifact: ", name)
  }

  version <- read_description_field(file, "Version")
  sha <- read_description_field(file, "RemoteSha")

  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.na(pkg_type)) {
    # Linux: single stable filename, always overwritten -- no repo index.
    dest <- file.path(target_dir, "MaxMin_latest.tar.gz")
    file.copy(file, dest, overwrite = TRUE)
  } else {
    # Windows/macOS: remove any previous MaxMin_* file(s) so exactly one
    # (the current) version is ever indexed, then let write_PACKAGES()
    # rebuild PACKAGES/.gz/.rds for the whole directory.
    old <- list.files(target_dir, pattern = "^MaxMin_.*\\.(zip|tgz)$",
                       full.names = TRUE)
    unlink(old)
    dest <- file.path(target_dir, basename(file))
    file.copy(file, dest, overwrite = TRUE)
    # `fields` pulls RemoteType/RemoteSha into the PACKAGES index itself
    # (write_PACKAGES() only includes a fixed default set otherwise), so a
    # stale artefact is auditable straight from the repo metadata, not just
    # from the installed DESCRIPTION.
    tools::write_PACKAGES(target_dir, type = pkg_type, verbose = TRUE,
                           fields = c("RemoteType", "RemoteSha"))
  }

  manifest[[tag]] <- list(
    version = version,
    sha = sha,
    file = dest,
    published_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

writeLines(
  jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
  "manifest.json"
)

cat("Published:\n")
str(manifest)
