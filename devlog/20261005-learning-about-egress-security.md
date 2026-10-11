---
layout: default
title: "Learning About Egress Security"
date: 2026-10-05
permalink: /devlog/20261005-learning-about-egress-security/
description: "Initial notes on monitoring and securing outbound traffic."
---

# Learning About Egress Security

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

For this draft, I am focusing on outbound connections to internet endpoints, including connections made after DNS resolution. DNS exfiltration is out of scope for now because it needs additional visibility and controls.

Data can be encoded into DNS query names and sent through permitted DNS traffic. Filtering the connections made after resolution would not catch that. Controlling resolver access, inspecting DNS queries, and handling encrypted DNS add complexity that I will leave for a separate discussion.

## What the end result looks like

Once implemented, we should be able to define which external endpoints our workloads can reach through allow and block lists, and see which connections were allowed or denied.

For example, a workload might be allowed to reach a payment API and an approved package registry, while a known malicious destination is blocked. With a default-deny policy, destinations outside the allow list would also be blocked. A block list alone would still permit unknown destinations unless another rule denies them.

An endpoint could mean an IP address and port, a domain name, or an application URL, depending on the control we choose. We need to enforce the policy across the workload's outbound paths so that a request cannot bypass it.

## What are the ways we can implement this?

There are a few places where we can apply these controls:

- **Network rules:** Security groups and network firewalls can restrict outbound traffic by IP address, port, and protocol. These are useful for basic restrictions, but IP-based rules become harder to maintain when external services change addresses or share infrastructure.
- **An egress proxy or gateway:** We can route outbound requests through a central point that applies policy and records connections. An HTTP proxy can support domain-based rules; filtering full HTTPS URLs generally requires TLS inspection because the path is encrypted. Direct outbound access must be restricted so workloads cannot bypass the proxy.
- **Workload-level controls:** Host firewalls or Kubernetes network policies can limit traffic close to the workload. Standard Kubernetes network policies mainly use IP and port rules; some networking implementations add domain-based policies and visibility into which workload made a connection.

These approaches can be combined. The choice depends on whether we need IP, domain, or URL filtering, which protocols our workloads use, and how we will maintain the endpoint lists. I will explore the implementation details next.
