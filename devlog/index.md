---
layout: default
title: Devlog
permalink: /devlog/
---

<nav class="tab-list" aria-label="Site sections">
  <a class="tab-label tab-label-intro" href="{{ '/' | relative_url }}">Intro</a>
  <a class="tab-label tab-label-devlog is-active" href="{{ '/devlog/' | relative_url }}" aria-current="page">Devlog</a>
  <a class="tab-label tab-label-profile" href="{{ '/profile/' | relative_url }}">Profile</a>
</nav>

<section class="devlog" aria-labelledby="devlog-title">
  <h2 id="devlog-title">Devlog</h2>

  <ol class="devlog-list">
    <li class="devlog-item">
      <time class="devlog-date" datetime="2026-07-03">July 3, 2026</time>
      <a class="devlog-link" href="{{ '/devlog/20260703-containers-from-scratch-rust-docker/' | relative_url }}">Containers From Scratch: Building a Tiny Docker Runtime in Rust</a>
    </li>
    <li class="devlog-item">
      <time class="devlog-date" datetime="2026-07-01">July 1, 2026</time>
      <a class="devlog-link" href="{{ '/devlog/20260701-ebpf-egress-monitor/' | relative_url }}">Demystifying eBPF: Building a Tiny Egress Monitor in Go</a>
    </li>
  </ol>
</section>
