import subprocess
import curses
import sys

def run_arp_scan(interface):
    cmd = ["arp-scan", "-l", "-I", interface]
    output = subprocess.check_output(cmd, universal_newlines=True)
    devices = parse_arp_scan_output(output)
    return devices

def parse_arp_scan_output(output):
    devices = {}
    lines = output.strip().split('\n')
    for line in lines:
        if line.startswith('10.1'):  # Modify this to match your network IP range
            parts = line.split('\t')
            ip = parts[0]
            mac = parts[1]
            name = parts[2] if len(parts) >= 3 else "Unknown"
            devices[mac] = (ip, name)
    return devices

def compare_scans(scan1, scan2):
    devices_only_in_scan1 = {mac: scan1[mac] for mac in scan1 if mac not in scan2}
    devices_only_in_scan2 = {mac: scan2[mac] for mac in scan2 if mac not in scan1}
    return devices_only_in_scan1, devices_only_in_scan2

def wait_for_keypress():
    stdscr = curses.initscr()
    stdscr.addstr("Press any key to continue...")
    stdscr.refresh()
    stdscr.getch()
    curses.endwin()

def print_devices(devices):
    for mac, (ip, name) in devices.items():
        print(f"IP: {ip}\tMAC: {mac}\tName: {name}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python arp_scan.py <interface>")
        return

    interface = sys.argv[1]
    print("Running first ARP scan...")
    scan1 = run_arp_scan(interface)
    print("First ARP scan completed.\n")

    wait_for_keypress()

    print("Running second ARP scan...")
    scan2 = run_arp_scan(interface)
    print("Second ARP scan completed.\n")

    devices_only_in_scan1, devices_only_in_scan2 = compare_scans(scan1, scan2)

    print("Devices only in first scan:")
    print_devices(devices_only_in_scan1)
    print("\nDevices only in second scan:")
    print_devices(devices_only_in_scan2)

if __name__ == "__main__":
    main()

