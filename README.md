# Linux System Monitor

A lightweight, Bash-based real-time system monitor that tracks CPU, memory, and disk usage and alerts when usage exceeds configurable thresholds. Simple and portable — ideal for quick diagnostics and learning Linux shell scripting. Tested on Fedora and other Linux distributions.

## Features
- Live CPU, memory, and disk usage display
- Colorized alerts when thresholds are exceeded
- Easy configuration via top-of-script variables
- No external dependencies beyond standard GNU/Linux tools

# Linux System Monitor

A lightweight, Bash-based real-time system monitor that tracks CPU, memory, and disk usage and alerts when usage exceeds configurable thresholds. Simple and portable — ideal for quick diagnostics and learning Linux shell scripting. Tested on Fedora and other Linux distributions.

## Features
- Live CPU, memory, and disk usage display
- Colorized alerts when thresholds are exceeded
- Easy configuration via top-of-script variables
- No external dependencies beyond standard GNU/Linux tools

## Prerequisites
- Bash (GNU bash)
- Common utilities: `top`, `free`, `df`, `awk`, `tput`

## Usage
1. Make the script executable:

```bash
chmod +x system_monitor.sh
```

2. Run the monitor:

```bash
./system_monitor.sh
```

3. Customize alert thresholds by editing the variables at the top of `system_monitor.sh`:

- `CPU_THRESHOLD`
- `MEMORY_THRESHOLD`
- `DISK_THRESHOLD`

The script refreshes every 2 seconds and prints a red alert message when a resource exceeds its threshold.

## Screenshot

Terminal output from the monitor:

![Terminal output](Images/Screenshot%20From%202026-02-08%2019-14-50.png)

## Contributing
Small fixes and improvements welcome — open an issue or submit a pull request.

## License
See the project `LICENSE` file for license details.
