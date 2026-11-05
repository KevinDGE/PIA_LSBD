/* Formulario de pago: formato del número, marca detectada y aviso de Luhn.
   La validación real ocurre en PHP y otra vez en SQL Server. */
(function () {
  'use strict';
  var num = document.getElementById('numero');
  var cvv = document.getElementById('cvv');
  var ayuda = document.getElementById('ayuda-numero');
  if (!num) { return; }

  function marca(n) {
    if (/^4/.test(n)) { return 'VISA'; }
    var p2 = parseInt(n.slice(0, 2), 10), p4 = parseInt(n.slice(0, 4), 10);
    if ((p2 >= 51 && p2 <= 55) || (p4 >= 2221 && p4 <= 2720)) { return 'MASTERCARD'; }
    if (/^3[47]/.test(n)) { return 'AMEX'; }
    return null;
  }
  function luhn(n) {
    var s = 0, d = false;
    for (var i = n.length - 1; i >= 0; i--) {
      var x = +n[i];
      if (d) { x *= 2; if (x > 9) { x -= 9; } }
      s += x; d = !d;
    }
    return n.length >= 13 && s % 10 === 0;
  }

  num.addEventListener('input', function () {
    var n = num.value.replace(/\D/g, '').slice(0, 19);
    var m = marca(n);
    var grupos = m === 'AMEX' ? [4, 6, 5] : [4, 4, 4, 4, 3];
    var partes = [], i = 0;
    grupos.forEach(function (g) { if (i < n.length) { partes.push(n.substr(i, g)); i += g; } });
    num.value = partes.join(' ');
    if (m) {
      var radio = document.querySelector('input[name="marca"][value="' + m + '"]');
      if (radio) { radio.checked = true; }
    }
    if (cvv) { cvv.maxLength = m === 'AMEX' ? 4 : 3; cvv.placeholder = m === 'AMEX' ? '••••' : '•••'; }
    var largo = m === 'AMEX' ? 15 : 16;
    if (n.length >= largo) {
      ayuda.textContent = luhn(n) ? '✓ Número válido (' + (m || 'marca no aceptada') + ')' : '✗ El número no pasa la validación de Luhn';
    } else {
      ayuda.textContent = m ? 'Marca detectada: ' + m : 'Visa, Mastercard o American Express';
    }
  });
})();
