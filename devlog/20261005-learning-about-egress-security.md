---
layout: default
title: "Learning About Egress Security — Part 1"
date: 2026-10-05
permalink: /devlog/20261005-learning-about-egress-security/
description: "Learning egress security through business requirements and system design."
---

# Learning About Egress Security — Part 1

> This devlog documents my learning journey on egress security while working on a business requirement. I am exploring the problem through system design, with the technical depth of an architect designing the system: understanding the requirements, the controls we need, and the tradeoffs between approaches.

## What is egress security?

Egress security is the monitoring and security of traffic initiated from within your network: from private or public workloads out to the internet.

## Don’t everyone do this?

Not really. Most organizations put more attention into incoming requests, using controls such as security groups and other perimeter protections.

## What it solves

Egress security gives us visibility and control over requests that begin inside our network. We can monitor where workloads connect, identify unexpected destinations, and apply policy to allow, filter, or block outbound traffic.

That matters when a workload, dependency, or package is compromised. A vulnerable or malicious package may try to download a second-stage payload, call a command-and-control server, or send data to an attacker-controlled endpoint. Egress controls can surface those connections and, when policy is in place, prevent them from succeeding.

The Log4j vulnerability is a useful example of the boundary. Egress controls do not fix the vulnerability or prevent the initial exploit. They can limit its blast radius by blocking a compromised service from reaching an attacker-controlled LDAP, HTTP, or command-and-control endpoint.

The same is true for Trojans and other malware. Egress security does not remove malware that is already present, but it can detect or block the outbound communication malware relies on for control, payload retrieval, and data transfer.

## DNS exfiltration is out of scope for now

In this part, I am focusing on outbound connections to internet endpoints, including connections made after DNS resolution. DNS exfiltration is out of scope for now because it needs additional visibility and controls.

Data can be encoded into DNS query names and sent through permitted DNS traffic. Filtering the connections made after resolution would not catch that. Controlling resolver access, inspecting DNS queries, and handling encrypted DNS add complexity that I will leave for a separate discussion.

## What the end result looks like

Once implemented, we should be able to define which external endpoints our workloads can reach through allow and block lists, and see which connections were allowed or denied.

For example, a workload might be allowed to reach a payment API and an approved package registry, while a known malicious destination is blocked. With a default-deny policy, destinations outside the allow list would also be blocked. A block list alone would still permit unknown destinations unless another rule denies them.

An endpoint could mean an IP address and port, a domain name, or an application URL, depending on the control we choose. We need to enforce the policy across the workload's outbound paths so that a request cannot bypass it.

## What are the ways we can implement this?

Several solutions can help us implement egress monitoring and filtering:

1. **Transparent proxy:** Intercepts outbound traffic without requiring each application to configure a proxy. It can apply destination policies and log requests, depending on the protocols and inspection it supports.
2. **Edge internet gateway:** Provides a central exit point for internet traffic where we can attach monitoring and policy enforcement. A basic internet or NAT gateway provides connectivity; filtering requires additional controls.
3. **Network firewall:** Inspects traffic on the outbound path and applies allow or block rules. Depending on its capabilities, rules can use IP addresses, ports, protocols, or domain names.
4. **Explicit forward proxy or secure web gateway:** Applications send web traffic through a configured proxy that enforces destination policies and records requests.
5. **Workload egress gateway and network policies:** Apply controls close to the workload, such as in a Kubernetes cluster, and route outbound traffic through a shared enforcement point.

These approaches can be combined. I will dive deeper into their system design and implementation tradeoffs in future devlogs.
