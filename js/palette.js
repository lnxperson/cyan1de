(() => {
    const root = document.documentElement;
    const swatches = document.querySelectorAll(".swatch[data-theme]");
    const storageKey = "cyan1de-site-theme";
    const themes = new Set(Array.from(swatches, (swatch) => swatch.dataset.theme));

    let saved = null;
    try {
        saved = localStorage.getItem(storageKey);
    } catch (error) {
        saved = null;
    }

    const applyTheme = (theme, save) => {
        if (!themes.has(theme)) {
            theme = "cyan";
        }

        root.dataset.theme = theme;

        swatches.forEach((swatch) => {
            const active = swatch.dataset.theme === theme;
            swatch.classList.toggle("is-active", active);
            swatch.setAttribute("aria-pressed", String(active));
        });

        if (save) {
            try {
                localStorage.setItem(storageKey, theme);
            } catch (error) {
                // Storage may be disabled; the theme still applies for this page.
            }
        }
    };

    applyTheme(saved || root.dataset.theme || "cyan", false);

    swatches.forEach((swatch) => {
        swatch.addEventListener("click", () => {
            applyTheme(swatch.dataset.theme, true);
        });
    });
})();
