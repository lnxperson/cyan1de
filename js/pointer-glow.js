(() => {
    const root = document.documentElement;
    const pulse = document.querySelector(".pointer-pulse");
    const finePointer = window.matchMedia("(pointer: fine)");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    if (!finePointer.matches || reducedMotion.matches) {
        return;
    }

    let targetX = window.innerWidth * 0.7;
    let targetY = window.innerHeight * 0.28;
    let currentX = targetX;
    let currentY = targetY;
    let frame = 0;
    let visible = false;

    const draw = () => {
        currentX += (targetX - currentX) * 0.14;
        currentY += (targetY - currentY) * 0.14;

        root.style.setProperty("--pointer-x", currentX.toFixed(1) + "px");
        root.style.setProperty("--pointer-y", currentY.toFixed(1) + "px");

        if (Math.abs(targetX - currentX) > 0.4 || Math.abs(targetY - currentY) > 0.4) {
            frame = requestAnimationFrame(draw);
        } else {
            frame = 0;
        }
    };

    const schedule = () => {
        if (!frame) {
            frame = requestAnimationFrame(draw);
        }
    };

    const show = () => {
        if (!visible) {
            visible = true;
            root.style.setProperty("--pointer-opacity", "1");
        }
    };

    const hide = () => {
        visible = false;
        root.style.setProperty("--pointer-opacity", "0");
    };

    window.addEventListener("pointermove", (event) => {
        if (event.pointerType && event.pointerType !== "mouse" && event.pointerType !== "pen") {
            return;
        }

        if (reducedMotion.matches) {
            hide();
            return;
        }

        targetX = event.clientX;
        targetY = event.clientY;
        show();
        schedule();
    }, { passive: true });

    document.documentElement.addEventListener("mouseleave", hide);
    window.addEventListener("blur", hide);

    if (pulse) {
        window.addEventListener("pointerdown", (event) => {
            if (event.button !== 0) {
                return;
            }

            pulse.style.setProperty("--pulse-x", event.clientX + "px");
            pulse.style.setProperty("--pulse-y", event.clientY + "px");
            pulse.classList.remove("is-pulsing");
            void pulse.offsetWidth;
            pulse.classList.add("is-pulsing");
        }, { passive: true });

        pulse.addEventListener("animationend", () => {
            pulse.classList.remove("is-pulsing");
        });
    }

    reducedMotion.addEventListener?.("change", (event) => {
        if (event.matches) {
            hide();
        }
    });
})();
