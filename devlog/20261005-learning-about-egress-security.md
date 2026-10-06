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

## DNS exfiltration: in scope?

DNS resolution is part of the egress path, so egress security can restrict which resolvers workloads use and which domains they can reach after resolution. That helps with monitoring and blocking suspicious destinations.

DNS exfiltration needs more specific controls. The data can be encoded into DNS query names and sent through permitted DNS traffic, so simply allowing DNS or filtering connections after resolution is not enough. Detecting it requires visibility into DNS queries and policies for resolvers, query names, and encrypted DNS. I will explore what belongs in this scope next.
