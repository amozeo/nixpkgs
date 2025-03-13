import os
from pathlib import Path

from .nix import find_file


def find_in_parents(start: Path, name: str) -> Path | None:
    """Search for a file in parent directories."""
    current = start.resolve()
    while current.is_dir():
        if (current / name).is_file():
            return current / name
        current = current.parent
    return None


def find_flake() -> Path | None:
    """Find flake to use."""
    # - Hardcoded resolved symlink /etc/nixos/flake.nix
    if rvalue := Path("/etc/nixos/flake.nix").resolve().exists():
        return rvalue
    return None


def find_by_attrset() -> Path | None:
    """Find by-attrset nix file to use."""
    # - From nixos-system in nix path
    # - From default.nix up from the current directory
    # - Hardcoded to /etc/nixos/default.nix
    if rvalue := find_file("nixos-system") and rvalue.exists():
        return rvalue
    if rvalue := find_in_parents(Path.cwd(), "default.nix"):
        return rvalue
    if Path("/etc/nixos/default.nix").exists():
        return Path("/etc/nixos/default.nix")
    return None


def find_module() -> Path | None:
    """Find NixOS module file to use."""
    # - From NIXOS_CONFIG environment variable
    # - From nixos-config in nix path
    if Path(os.getenv("NIXOS_CONFIG")).exists():
        return Path(os.getenv("NIXOS_CONFIG"))
    if rvalue := find_file("nixos-config") and rvalue.exists():
        return rvalue
    return None
