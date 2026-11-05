/* Selección de asientos: respeta el máximo permitido y muestra el total.
   Es solo ayuda visual: el servidor y la base vuelven a validar todo. */
(function () {
  'use strict';
  var form = document.getElementById('form-asientos');
  if (!form) { return; }
  var max = parseInt(form.getAttribute('data-max'), 10) || 0;
  var precio = parseFloat(form.getAttribute('data-precio')) || 0;
  var lista = document.getElementById('sel-lista');
  var cantidad = document.getElementById('sel-cantidad');
  var total = document.getElementById('sel-total');
  var boton = document.getElementById('btn-continuar');
  var casillas = Array.prototype.slice.call(form.querySelectorAll('input[name="asientos[]"]'));
  var fmt = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });

  function actualizar() {
    var elegidos = casillas.filter(function (c) { return c.checked; });
    casillas.forEach(function (c) {
      c.parentElement.classList.toggle('seleccionado', c.checked);
      if (!c.hasAttribute('data-bloqueado-servidor')) {
        c.disabled = c.hasAttribute('data-ocupado') || (!c.checked && elegidos.length >= max);
      }
    });
    lista.textContent = elegidos.length
      ? elegidos.map(function (c) { return c.getAttribute('data-etq'); }).join(', ')
      : 'Ningún asiento seleccionado';
    cantidad.textContent = elegidos.length + (max ? ' de ' + max + ' máx.' : '');
    total.textContent = fmt.format(elegidos.length * precio);
    boton.disabled = elegidos.length === 0;
  }

  casillas.forEach(function (c) {
    if (c.disabled) { c.setAttribute('data-ocupado', '1'); }
    c.addEventListener('change', actualizar);
  });
  form.addEventListener('submit', function (ev) {
    var n = casillas.filter(function (c) { return c.checked; }).length;
    if (n === 0 || n > max) { ev.preventDefault(); }
  });
  actualizar();
})();
