---
layout: default
---

<div class="tabs">
  <input class="tab-input" type="radio" name="home-tabs" id="tab-about" checked>
  <input class="tab-input" type="radio" name="home-tabs" id="tab-devlog">

  <nav class="tab-list" aria-label="Home sections">
    <label class="tab-label tab-label-about" for="tab-about">About</label>
    <label class="tab-label tab-label-devlog" for="tab-devlog">Devlog</label>
  </nav>

  <section class="tab-panel about-panel" aria-labelledby="tab-about">
    <section class="hero" aria-labelledby="site-title">
      <p class="eyebrow">developer · platform engineer · systems tinkerer</p>
      <h1 id="site-title">{ Sharran M }</h1>
      <p class="lede">
        I keep a devlog of what I develop, learn, explore, and work through in my
        personal time.
      </p>
    </section>

    <section class="social-links" aria-label="Social links">
      <a href="https://www.linkedin.com/in/sharran-m" rel="me">LinkedIn</a>
      <a href="https://github.com/msharran" rel="me">GitHub</a>
      <a href="https://x.com/msharran97" rel="me">X.com</a>
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
        All my pet projects are spread across in my GitHub account, while the
        following are well structured to take a look around. I mostly program in Go
        and Zig, while also occasionally program in Rust and C (to satisfy my
        curiosity, not a pro here).
      </p>
      <ul>
        <li><a href="https://github.com/msharran/codingchallenges.fyi">https://github.com/msharran/codingchallenges.fyi</a></li>
        <li><a href="https://github.com/msharran/protohackers.com">https://github.com/msharran/protohackers.com</a></li>
        <li><a href="https://github.com/msharran/wasm-poc">https://github.com/msharran/wasm-poc</a></li>
      </ul>
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
    </section>
  </section>

  <section class="tab-panel devlog-panel" aria-labelledby="tab-devlog">
    <section class="devlog" aria-labelledby="devlog-title">
      <h2 id="devlog-title">Devlog</h2>

      {% if site.posts.size > 0 %}
        <ol class="devlog-list">
          {% for post in site.posts %}
            <li class="devlog-item">
              <a class="devlog-link" href="{{ post.url | relative_url }}">{{ post.title }}</a>
              <time class="devlog-date" datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %-d, %Y" }}</time>
            </li>
          {% endfor %}
        </ol>
      {% else %}
        <ol class="devlog-list empty-devlog">
          <li class="devlog-item">
            <span class="devlog-link">Notes from what I’m building, learning, and exploring will show up here.</span>
            <span class="devlog-date">Soon</span>
          </li>
        </ol>
      {% endif %}
    </section>
  </section>
</div>
