(() => {
  /* ---------------------------------------------------------------------
     Reveal animations
     --------------------------------------------------------------------- */
  const reveals = document.querySelectorAll('.reveal');
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (!('IntersectionObserver' in window) || reduced) {
    reveals.forEach(el => el.classList.add('is-visible'));
  } else {
    const io = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      }
    }, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });
    reveals.forEach(el => io.observe(el));
  }

  /* ---------------------------------------------------------------------
     Yard iframe contract — v1
     See ~/.claude/skills/yard/references/custom-landing-pages.md
     --------------------------------------------------------------------- */

  const setText = (selector, text) => {
    document.querySelectorAll(selector).forEach(el => { el.textContent = text; });
  };

  const formatPrice = (cents) => {
    const dollars = cents / 100;
    return dollars % 1 === 0 ? `$${dollars}` : `$${dollars.toFixed(2)}`;
  };

  const stateLabelFor = (state) => ({
    released: 'Available now',
    preorder: 'Pre-order',
    early_access: 'Early Access',
    draft: 'Coming soon',
  }[state] || 'Available now');

  const renderProduct = (product) => {
    document.title = product.title;

    setText('.js-product-title', product.title);

    const cents = product.discountedPriceCents ?? product.priceCents;
    setText('.js-price', formatPrice(cents));
    setText('.js-price-amount', String(Math.trunc(cents / 100)));

    const latest = product.releases && product.releases[0];
    const version = latest ? `v${latest.tagName.replace(/^v/, '')}` : null;
    document.querySelectorAll('.js-version').forEach(el => {
      if (version) { el.textContent = version; el.hidden = false; }
      else el.hidden = true;
    });

    const stateLabel = stateLabelFor(product.state);
    setText('.js-state-label', version ? `${stateLabel} — ${version}` : stateLabel);

    document.querySelectorAll('.js-trial').forEach(el => {
      el.hidden = !product.freeTrialEnabled;
    });
  };

  const showResult = (msg) => {
    const banner = document.getElementById('yard-result');
    if (!banner) return;
    banner.textContent = msg.status === 'success'
      ? 'Added to your library. Check your email for the download link.'
      : `Checkout error: ${msg.message || 'please try again'}`;
    banner.dataset.status = msg.status;
    banner.hidden = false;
  };

  window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg !== 'object' || msg.v !== 1) return;
    if (msg.type === 'yard:product') renderProduct(msg.product);
    if (msg.type === 'yard:checkout:result') showResult(msg);
  });

  document.addEventListener('click', (e) => {
    const checkoutEl = e.target.closest('.js-checkout');
    if (checkoutEl) {
      e.preventDefault();
      const payload = { type: 'yard:checkout', v: 1 };
      const { tier, quantity, interval, gift } = checkoutEl.dataset;
      if (tier) payload.tierId = tier;
      const q = Number(quantity);
      if (q > 1) payload.quantity = q;
      if (interval) payload.interval = interval;
      if (gift === 'true') payload.gift = true;
      parent.postMessage(payload, '*');
      return;
    }
    const trialEl = e.target.closest('.js-trial');
    if (trialEl) {
      e.preventDefault();
      parent.postMessage({ type: 'yard:trial', v: 1 }, '*');
    }
  });

  parent.postMessage({ type: 'yard:ready', v: 1 }, '*');
})();
