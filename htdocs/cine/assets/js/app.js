/* Comportamientos comunes. Sin JavaScript en línea (la CSP lo bloquea). */
(function () {
  'use strict';

  // Menú en pantallas chicas
  var btn = document.querySelector('[data-menu]');
  var menu = document.getElementById('menu-principal');
  if (btn && menu) {
    btn.addEventListener('click', function () {
      var abierto = menu.classList.toggle('abierto');
      btn.setAttribute('aria-expanded', abierto ? 'true' : 'false');
    });
  }

  // Botón imprimir boletos
  document.querySelectorAll('[data-imprimir]').forEach(function (b) {
    b.addEventListener('click', function () { window.print(); });
  });

  // Confirmación antes de enviar formularios peligrosos
  document.querySelectorAll('form[data-confirmar]').forEach(function (f) {
    f.addEventListener('submit', function (ev) {
      if (!window.confirm(f.getAttribute('data-confirmar'))) { ev.preventDefault(); }
    });
  });

  // Evita doble envío
  document.querySelectorAll('button[data-enviando]').forEach(function (b) {
    var form = b.form;
    if (!form) { return; }
    form.addEventListener('submit', function (ev) {
      if (ev.defaultPrevented) { return; }
      setTimeout(function () { b.disabled = true; b.textContent = b.getAttribute('data-enviando'); }, 0);
    });
  });

  // Barras de porcentaje (ancho desde data-pct)
  window.pintarBarras = function (raiz) {
    (raiz || document).querySelectorAll('[data-pct]').forEach(function (el) {
      var p = Math.max(0, Math.min(100, parseInt(el.getAttribute('data-pct'), 10) || 0));
      el.style.width = p + '%';
    });
  };
  window.pintarBarras();
})();
