# Glossary

Domain terms only. Technical terms stay in the plan and the README.

**Agent**
The program that watches the home LAN for the user. It scans, pings, checks ports, and wakes devices.
_Avoid_: server, bot

**Client**
The dashboard that the user holds. It shows device status and sends the user's text to the agent.
_Avoid_: app, frontend

**Device**
A machine on the home LAN. A device is registered (the registry names it) or unregistered.
_Avoid_: host, node

**Registry**
The list of registered devices. It maps a device name to its MAC address and IP address.
_Avoid_: inventory

**Model**
The open-weight language model that answers free text for the agent. The model never runs commands.
_Avoid_: AI, LLM

**Scan**
One check of the home LAN for devices and their current availability.
