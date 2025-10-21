# Firewall-manager
 
Requirements

Windows 10 / 11 or Windows Server
PowerShell 5.1 or later
Administrative privileges (required for modifying firewall rules)

This PowerShell project provides an interactive firewall management tool that allows users to create, modify, enable, disable, back up, and restore Windows Firewall rules through a simple terminal menu.
It also supports JSON-based rule configuration, CSV export, and system-wide backup/restore using .wfw files.

Main Menu Options
#	Option	Description
1	Add or update rule	Create a new rule or update an existing one
2	Remove rule	Delete a rule from both system and JSON
3	Edit rule	Modify an existing rule’s parameters
4	Show rules from JSON	Display all locally stored rules
5	Show all system firewall rules	Display all rules configured in Windows
6	Enable rule	Enable a specific rule
7	Disable rule	Disable a specific rule
8	Export rules to CSV	Export JSON rules to a .csv file
9	Enable all rules from JSON	Add or enable all rules defined in JSON
10	Backup full system firewall	Create .wfw system backup
11	Restore full system firewall	Restore .wfw backup
12	Exit	Quit the application

Example
Welcome to Interactive Firewall Manager

Select an option:
1. Add or update rule
2. Remove rule
3. Edit rule
...
Enter option number: 1

Enter rule name: WebServer
Enter direction (in/out): in
Enter action (allow/block): allow
Enter protocol (TCP/UDP): TCP
Enter local port (1-65535): 80
Enter remote port (leave blank for any):
Enter profile (any/private/public/domain): any

Rule added/updated and saved.



Firewall Monitoring Module
firewall_monitor.ps1

A real-time event monitoring script that continuously scans Windows Event Logs for firewall-related changes and logs them into a structured .jsonl file.
This module is ideal for auditing, incident analysis, or security research related to system configuration changes.