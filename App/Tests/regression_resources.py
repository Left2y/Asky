"""Keep the SwiftPM localization bundle beside native regression executables."""
import shutil


def copy_core_resources(products, destination):
    source = products / "KulaCore_Contracts.bundle"
    if not source.is_dir():
        raise SystemExit("Build the Debug app first: KulaCore_Contracts.bundle is missing.")
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination / source.name, dirs_exist_ok=True)
