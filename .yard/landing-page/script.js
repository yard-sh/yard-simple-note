(() => {
  'use strict';

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /** Small DOM helper: el('div', { class: 'x', text: 'y' }, [children]) */
  const el = (tag, props = {}, children = []) => {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props)) {
      if (value === undefined || value === null || value === false) continue;
      if (key === 'class') node.className = value;
      else if (key === 'text') node.textContent = value;
      else if (key === 'on') Object.entries(value).forEach(([evt, fn]) => node.addEventListener(evt, fn));
      else node.setAttribute(key, value === true ? '' : String(value));
    }
    for (const child of [].concat(children)) if (child) node.append(child);
    return node;
  };

  /* =====================================================================
     The working app preview
     ===================================================================== */

  const demo = document.querySelector('[data-demo]');
  if (demo) {
    const now = new Date();
    const minutesAgo = (m) => new Date(now.getTime() - m * 60000);
    const notes = [
      {
        title: 'Sunday ideas',
        date: minutesAgo(18),
        body: 'Not another system. Not another place to organise your life.\n\nJust a small place to write things down while they’re still warm.',
        typed: ' Keep it close.',
      },
      {
        title: 'Reading list',
        date: minutesAgo(95),
        body: 'Three essays to come back to:\n— On keeping a notebook\n— The tyranny of the inbox\n— Slow software',
      },
      {
        title: 'Call with Mina',
        date: minutesAgo(60 * 26),
        body: 'Keep the first version small. Ship it, then listen.\n\nShe liked the idea of one window and nothing else.',
      },
      {
        title: 'Groceries',
        date: minutesAgo(60 * 50),
        body: 'Lemons, good bread, coffee beans, the nice butter.',
      },
    ];

    const list = demo.querySelector('[data-demo-list]');
    const search = demo.querySelector('[data-demo-search]');
    const meta = demo.querySelector('[data-demo-meta]');
    const title = demo.querySelector('[data-demo-title]');
    const body = demo.querySelector('[data-demo-body]');
    let selected = 0;
    let saveTimer;
    let typing;

    const sameDay = (a, b) => a.toDateString() === b.toDateString();
    const section = (d) => (sameDay(d, now) ? 'Today' : sameDay(d, new Date(now.getTime() - 864e5)) ? 'Yesterday' : 'Previous 7 Days');
    const time = (d) => (sameDay(d, now)
      ? d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
      : section(d) === 'Yesterday' ? 'Yesterday' : d.toLocaleDateString([], { weekday: 'short' }));
    const words = (text) => (text.trim().match(/\S+/g) || []).length;

    const renderMeta = (state = 'Saved') => {
      const note = notes[selected];
      const day = note.date.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
      const clock = note.date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
      const count = words(note.body);
      meta.replaceChildren(
        `${day} · ${clock} · ${count} word${count === 1 ? '' : 's'} · `,
        el('span', { class: state === 'Saved' ? 'saved' : '', text: state === 'Saved' ? '● Saved' : state }),
      );
    };

    const renderList = () => {
      const q = search.value.trim().toLowerCase();
      const visible = notes
        .map((note, index) => ({ note, index }))
        .filter(({ note }) => !q || note.title.toLowerCase().includes(q) || note.body.toLowerCase().includes(q));
      list.replaceChildren();
      let lastSection = '';
      for (const { note, index } of visible) {
        const s = section(note.date);
        if (s !== lastSection) {
          list.append(el('div', { class: 'notes__section', text: s }));
          lastSection = s;
        }
        list.append(el('button', {
          type: 'button',
          class: 'note-row',
          role: 'option',
          'aria-selected': index === selected ? 'true' : 'false',
          on: { click: () => select(index) },
        }, [
          el('span', { class: 'note-row__top' }, [
            el('span', { class: 'note-row__title', text: note.title }),
            el('span', { class: 'note-row__time', text: time(note.date) }),
          ]),
          el('span', { class: 'note-row__preview', text: note.body.replace(/\s+/g, ' ') }),
        ]));
      }
      if (!visible.length) list.append(el('p', { class: 'notes__empty', text: `No notes match “${search.value.trim()}”.` }));
    };

    const select = (index) => {
      stopTyping();
      selected = index;
      title.textContent = notes[index].title;
      body.textContent = notes[index].body;
      renderMeta();
      renderList();
    };

    const stopTyping = () => {
      if (!typing) return;
      clearInterval(typing);
      typing = null;
      const note = notes[0];
      if (note.typed) { note.body += note.typed; note.typed = ''; }
      if (selected === 0) body.textContent = note.body;
    };

    body.addEventListener('input', () => {
      stopTyping();
      notes[selected].body = body.innerText;
      notes[selected].date = new Date();
      renderMeta('Editing…');
      clearTimeout(saveTimer);
      saveTimer = setTimeout(() => { renderMeta(); renderList(); }, 450);
    });
    body.addEventListener('focus', stopTyping);
    search.addEventListener('input', renderList);

    select(0);

    // One moment of motion: finish the first note's sentence once the preview is on screen.
    const first = notes[0];
    if (!reducedMotion && first.typed && 'IntersectionObserver' in window) {
      const io = new IntersectionObserver((entries) => {
        if (!entries.some((e) => e.isIntersecting)) return;
        io.disconnect();
        let i = 0;
        typing = setInterval(() => {
          if (selected !== 0) return stopTyping();
          i += 1;
          body.textContent = first.body + first.typed.slice(0, i);
          if (i >= first.typed.length) stopTyping();
        }, 55);
      }, { threshold: 0.5 });
      setTimeout(() => io.observe(demo), 600);
    } else {
      stopTyping();
    }
  }

  /* =====================================================================
     Live project data from Yard (window.yard.project)
     Checkout and trial clicks on [data-action] are handled by Yard's
     embed.js; this only builds the elements and fills in live data.
     ===================================================================== */

  const project = window.yard && window.yard.project;
  if (!project) return;

  const money = (cents) => {
    const hasCents = Math.round(cents) % 100 !== 0;
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: hasCents ? 2 : 0,
      maximumFractionDigits: 2,
    }).format(cents / 100);
  };

  // App icon in the navigation.
  const icon = (project.images || []).find((img) => img.image_type === 'icon');
  const iconEl = document.querySelector('[data-icon]');
  if (icon && iconEl) {
    iconEl.src = icon.url;
    iconEl.hidden = false;
  }

  // Current version next to the hero buttons.
  const tag = project.latest_release && project.latest_release.tag_name;
  const versionEl = document.querySelector('[data-version]');
  if (tag && versionEl) {
    versionEl.textContent = `Version ${tag.replace(/^v/, '')}`;
    versionEl.hidden = false;
  }

  const tiers = (project.tiers || []).slice().sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

  // Trials are per tier: offer the hero trial only when a tier has one, and name that tier.
  const trialTier = tiers.find((t) => t.free_trial && t.free_trial.enabled);
  const heroTrial = document.querySelector('[data-hero-trial]');
  if (trialTier && heroTrial) {
    heroTrial.dataset.tierId = trialTier.key;
    heroTrial.textContent = trialTier.free_trial.days
      ? `Try it free for ${trialTier.free_trial.days} days`
      : 'Try it free';
    heroTrial.hidden = false;
  }

  /* ---------- Plans ---------- */

  const plansEl = document.querySelector('[data-plans]');
  if (!plansEl || !tiers.length) return;

  const isSubscription = (t) => t.pricing_model === 'subscription';
  const yearlyDiscount = (t) => (isSubscription(t) && t.yearly_discount_percent > 0 ? t.yearly_discount_percent : 0);
  const offersYearly = tiers.some((t) => yearlyDiscount(t) > 0);
  let interval = 'monthly';

  const seatState = new Map(); // tier key -> chosen seat count

  const bracketDiscount = (tier, qty) => {
    const bracket = (tier.volume_brackets || []).find(
      (b) => qty >= b.min_quantity && (b.max_quantity == null || qty <= b.max_quantity),
    );
    return bracket ? bracket.discount_percent : 0;
  };

  const renderPlan = (tier) => {
    const sub = isSubscription(tier);
    const perSeat = tier.seat_type === 'per_seat';
    const minSeats = Math.max(1, tier.min_seats || 1);
    const maxSeats = tier.max_seats || 999;
    const seats = perSeat ? (seatState.get(tier.key) ?? minSeats) : 1;
    const yearly = sub && interval === 'yearly' && yearlyDiscount(tier) > 0;

    // Price shown: per seat for per-seat tiers, with the volume discount for the chosen count.
    const volume = perSeat ? bracketDiscount(tier, seats) : 0;
    const unitMonthly = tier.price_cents * (1 - volume / 100);
    const shown = yearly ? unitMonthly * 12 * (1 - yearlyDiscount(tier) / 100) : unitMonthly;

    let period = sub ? (yearly ? 'per year' : 'per month') : 'one-time purchase';
    if (perSeat) period = sub ? `per seat, ${yearly ? 'per year' : 'per month'}` : 'per seat';
    if (tier.seat_type === 'fixed_pack' && tier.seat_count) period += `, ${tier.seat_count} seats`;

    const priceNotes = [];
    if (perSeat && seats > 1) priceNotes.push(`${money(shown * seats)} for ${seats} seats`);
    if (volume) priceNotes.push(`${volume}% off at ${seats} seat${seats === 1 ? '' : 's'}`);
    if (yearly) priceNotes.push(`Save ${yearlyDiscount(tier)}%`);

    const checkout = el('button', {
      type: 'button',
      class: 'button',
      'data-action': 'checkout',
      'data-tier-id': tier.key,
      'data-interval': sub ? (yearly ? 'yearly' : 'monthly') : null,
      'data-quantity': perSeat ? String(seats) : null,
      text: sub ? `Subscribe to ${tier.name}` : `Buy ${tier.name}`,
    });

    const secondary = [];
    if (tier.free_trial && tier.free_trial.enabled) {
      secondary.push(el('button', {
        type: 'button',
        class: 'button button--plain',
        'data-action': 'trial',
        'data-tier-id': tier.key,
        text: tier.free_trial.days ? `Try free for ${tier.free_trial.days} days` : 'Try it free',
      }));
    }
    // Gifts are for one-time tiers only.
    if (tier.gift_enabled && !sub) {
      secondary.push(el('button', {
        type: 'button',
        class: 'button button--plain',
        'data-action': 'checkout',
        'data-tier-id': tier.key,
        'data-gift': true,
        'data-quantity': perSeat ? String(seats) : null,
        text: 'Buy as a gift',
      }));
    }

    const setSeats = (n) => {
      seatState.set(tier.key, Math.min(maxSeats, Math.max(minSeats, n)));
      renderPlans();
      plansEl.querySelector(`[data-stepper="${CSS.escape(tier.key)}"] output`)?.focus();
    };

    const features = (tier.features || []).filter(Boolean).slice(0, 6);

    return el('article', { class: 'plan', 'aria-label': tier.name }, [
      el('div', {}, [
        el('h3', { class: 'plan__name', text: tier.name }),
        tier.description ? el('p', { class: 'plan__description', text: tier.description }) : null,
        features.length ? el('ul', { class: 'plan__features' }, features.map((f) => el('li', { text: f }))) : null,
        perSeat ? el('div', { class: 'seats' }, [
          el('span', { id: `seats-${tier.key}`, text: 'Seats' }),
          el('span', { class: 'stepper', 'data-stepper': tier.key, role: 'group', 'aria-labelledby': `seats-${tier.key}` }, [
            el('button', { type: 'button', 'aria-label': 'Fewer seats', disabled: seats <= minSeats, text: '−', on: { click: () => setSeats(seats - 1) } }),
            el('output', { tabindex: '-1', 'aria-live': 'polite', text: String(seats) }),
            el('button', { type: 'button', 'aria-label': 'More seats', disabled: seats >= maxSeats, text: '+', on: { click: () => setSeats(seats + 1) } }),
          ]),
        ]) : null,
      ]),
      el('div', { class: 'plan__price' }, [
        el('span', { class: 'plan__amount', text: money(shown) }),
        el('span', { class: 'plan__period', text: period }),
        ...priceNotes.map((n) => el('span', { class: 'plan__note', text: n })),
      ]),
      el('div', { class: 'plan__actions' }, [
        checkout,
        secondary.length ? el('div', { class: 'plan__secondary' }, secondary) : null,
      ]),
    ]);
  };

  const renderPlans = () => {
    plansEl.replaceChildren(...tiers.map(renderPlan));
  };

  // Monthly / yearly switch, only when some subscription tier discounts yearly billing.
  const billing = document.querySelector('[data-billing]');
  if (billing && offersYearly) {
    const best = Math.max(...tiers.map(yearlyDiscount));
    const save = billing.querySelector('[data-yearly-save]');
    if (save) save.textContent = `save ${best}%`;
    const choices = billing.querySelectorAll('[data-billing-choice]');
    choices.forEach((btn) => btn.addEventListener('click', () => {
      interval = btn.dataset.billingChoice;
      choices.forEach((b) => b.setAttribute('aria-checked', String(b === btn)));
      renderPlans();
    }));
    billing.hidden = false;
  }

  renderPlans();
})();
