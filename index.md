---
layout: default
---

<div class="tabs">
  <nav class="tab-list" aria-label="Site sections">
    <a class="tab-label tab-label-intro is-active" href="{{ '/' | relative_url }}" aria-current="page">Intro</a>
    <a class="tab-label tab-label-devlog" href="{{ '/devlog/' | relative_url }}">Devlog</a>
    <a class="tab-label tab-label-profile" href="{{ '/profile/' | relative_url }}">Profile</a>
  </nav>

  <section class="about-panel" aria-labelledby="site-title">
    <section class="hero" aria-labelledby="site-title">
      <p class="eyebrow">developer · platform engineer · systems tinkerer</p>
      <h1 id="site-title">{ Sharran M }</h1>
      <p class="lede">
        I keep a devlog of what I develop, learn, explore, and work through in my
        personal time.
      </p>
    </section>

    <section class="social-links" aria-labelledby="follow-title">
      <h2 id="follow-title">Follow Sharran</h2>
      <ul class="social-icon-list">
        <li>
          <a href="https://x.com/msharran97" rel="me" aria-label="Follow Sharran on X.com">
            <svg aria-hidden="true" viewBox="0 0 24 24" focusable="false">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817-5.963 6.817H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231Zm-1.161 17.52h1.833L7.084 4.126H5.117Z" />
            </svg>
          </a>
        </li>
        <li>
          <a href="https://github.com/msharran" rel="me" aria-label="Follow Sharran on GitHub">
            <svg aria-hidden="true" viewBox="0 0 24 24" focusable="false">
              <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56 0-.28-.01-1.02-.02-2-3.2.7-3.88-1.54-3.88-1.54-.52-1.33-1.28-1.69-1.28-1.69-1.04-.71.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.76 2.7 1.25 3.35.96.1-.75.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.68 0-1.25.45-2.28 1.18-3.08-.12-.29-.51-1.46.11-3.04 0 0 .97-.31 3.16 1.18A10.98 10.98 0 0 1 12 5.52c.98.01 1.96.13 2.88.39 2.2-1.49 3.16-1.18 3.16-1.18.63 1.58.24 2.75.12 3.04.74.8 1.18 1.83 1.18 3.08 0 4.42-2.69 5.38-5.25 5.67.41.36.78 1.06.78 2.14 0 1.54-.02 2.78-.02 3.16 0 .31.21.67.79.56A11.52 11.52 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
            </svg>
          </a>
        </li>
        <li>
          <a href="https://www.linkedin.com/in/sharran-m" rel="me" aria-label="Connect with Sharran on LinkedIn">
            <svg aria-hidden="true" viewBox="0 0 24 24" focusable="false">
              <path d="M20.45 20.45h-3.56v-5.57c0-1.33-.02-3.04-1.85-3.04-1.85 0-2.14 1.45-2.14 2.95v5.66H9.34V8.98h3.42v1.57h.05a3.75 3.75 0 0 1 3.37-1.85c3.6 0 4.27 2.37 4.27 5.46v6.29ZM5.32 7.41a2.06 2.06 0 1 1 0-4.12 2.06 2.06 0 0 1 0 4.12Zm1.78 13.04H3.54V8.98H7.1v11.47ZM22.22 0H1.77C.79 0 0 .77 0 1.73v20.54C0 23.23.79 24 1.77 24h20.45c.98 0 1.78-.77 1.78-1.73V1.73C24 .77 23.2 0 22.22 0Z" />
            </svg>
          </a>
        </li>
      </ul>
    </section>

    <section class="who-i-am" aria-labelledby="who-title">
      <h2 id="who-title">Who I am</h2>
      <p>
        I’m a software engineer based in Bangalore, India — currently working on
        infrastructure tooling domain.
      </p>
      <p>
        At work, I develop systems and tooling for platform engineering problems in
        developer experience and software delivery charter.
      </p>
      <p>
        Personally, I’m also curious about systems software and network programming.
        So, In my free time, I pick and solve challenges from
        <a href="https://protohackers.com">protohackers.com</a> or
        <a href="https://codingchallenges.fyi">codingchallenges.fyi</a>. I don’t
        finish it end to end because my goal is to learn something substantial
        before it gets boring.
      </p>
      <p>
        All my pet projects are spread across in my GitHub account. I mostly
        program in Go and Zig, while also occasionally program in Rust and C (to
        satisfy my curiosity, not a pro here). The well structured ones are linked
        at the end of this section.
      </p>
      <p>
        Lately I’m very interested in eBPF and trying to implement a
        <code>syscall</code> tracer using <code>libebpfgo</code> package. I will
        reflect about it later.
      </p>
      <p>
        I also love to tweak my development setup a lot (my current editor and
        harness of choice are <code>zed</code> and <code>pi</code> respectively).
        Most of my <code>.dotfiles</code> (few configs are redacted to my private
        dotfiles repo) and my custom <code>pi</code> extensions are pushed to the
        following repositories.
      </p>
      <ul>
        <li><a href="https://github.com/msharran/.dotfiles">https://github.com/msharran/.dotfiles</a></li>
        <li><a href="https://github.com/msharran/pi-amplike-modes">https://github.com/msharran/pi-amplike-modes</a></li>
        <li><a href="https://github.com/msharran/pragmatic-pi-extensions">https://github.com/msharran/pragmatic-pi-extensions</a></li>
      </ul>
      <p>
        This site will be my devlog. I will reflect on the above areas of interest
        in concise log entries — in my own language, unstructured and unfiltered,
        acting as a brain dump of what I have learnt.
      </p>
      <ul class="project-links" aria-label="Structured project links">
        <li><a href="https://github.com/msharran/codingchallenges.fyi">https://github.com/msharran/codingchallenges.fyi</a></li>
        <li><a href="https://github.com/msharran/protohackers.com">https://github.com/msharran/protohackers.com</a></li>
        <li><a href="https://github.com/msharran/wasm-poc">https://github.com/msharran/wasm-poc</a></li>
      </ul>
    </section>
  </section>
</div>
