import subprocess
import sys

# Define network profiles
PROFILES = {
    "ethernet": {"delay": "1ms", "rate": None, "loss": None},
    "wifi": {"delay": "20ms", "rate": None, "loss": "1%"},
    "4g": {"delay": "50ms", "rate": "20mbit", "loss": "1%"},
    "5g": {"delay": "10ms", "rate": "100mbit", "loss": None},
    "clear": None,  # Special case to reset configuration
}


def run_command(cmd):
    """Run a shell command and print it"""
    print(f"Executing: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def clear_tc(interface):
    """Clear any existing traffic control rules"""
    run_command(["tc", "qdisc", "del", "dev", interface, "root"])


def apply_profile(profile_name, interface):
    """Apply a selected network profile to a given interface"""
    if profile_name not in PROFILES:
        print(f"Unknown profile '{profile_name}'")
        print(f"Available profiles: {', '.join(PROFILES.keys())}")
        return

    if profile_name == "clear":
        clear_tc(interface)
        print("Cleared all network emulation settings.")
        return

    clear_tc(interface)

    profile = PROFILES[profile_name]

    if profile["rate"]:
        # Use Token Bucket Filter for bandwidth control
        cmd = [
            "tc",
            "qdisc",
            "add",
            "dev",
            interface,
            "root",
            "handle",
            "1:",
            "tbf",
            "rate",
            profile["rate"],
            "burst",
            "32kbit",
            "latency",
            profile["delay"],
        ]
    else:
        # Use netem for delay/loss only
        cmd = ["tc", "qdisc", "add", "dev", interface, "root", "netem"]
        if profile["delay"]:
            cmd += ["delay", profile["delay"]]
        if profile["loss"]:
            cmd += ["loss", profile["loss"]]

    run_command(cmd)
    print(f"Applied profile '{profile_name}' to interface '{interface}'.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: sudo python3 network_emulator.py <profile> <interface>")
        print(f"Available profiles: {', '.join(PROFILES.keys())}")
        sys.exit(1)

    profile = sys.argv[1].lower()
    interface = sys.argv[2]
    apply_profile(profile, interface)
