/* Panel en vivo: consulta admin/api_resumen.php cada 5 segundos.
   Todo se inserta con textContent (nunca innerHTML con datos). */
(function () {
  'use strict';
  var panel = document.getElementById('panel-vivo');
  if (!panel) { return; }
  var api = panel.getAttribute('data-api');
  var estado = document.getElementById('estado-vivo');
  var actualizado = document.getElementById('actualizado');
  var tbody = document.getElementById('tabla-vendidas');
  var listaPelis = document.getElementById('lista-peliculas');

  function celda(tr, texto, clase) {
    var td = document.createElement('td');
    td.textContent = texto;
    if (clase) { td.className = clase; }
    tr.appendChild(td);
    return td;
  }

  function barra(pct, clase) {
    var b = document.createElement('span');
    b.className = clase;
    var r = document.createElement('span');
    r.style.width = Math.max(0, Math.min(100, pct)) + '%';
    b.appendChild(r);
    return b;
  }

  function pintar(d) {
    Object.keys(d.kpi).forEach(function (k) {
      var el = panel.querySelector('[data-kpi="' + k + '"]');
      if (el && el.textContent !== String(d.kpi[k])) {
        el.textContent = d.kpi[k];
        el.classList.remove('cambio'); void el.offsetWidth; el.classList.add('cambio');
      }
    });
    actualizado.textContent = d.actualizado;

    tbody.replaceChildren();
    if (!d.vendidas.length) {
      var tr0 = document.createElement('tr');
      var td0 = celda(tr0, 'Aún no hay ventas.'); td0.colSpan = 6;
      tbody.appendChild(tr0);
    }
    d.vendidas.forEach(function (f) {
      var tr = document.createElement('tr');
      var t = celda(tr, f.titulo);
      if (!f.activa) { var s = document.createElement('span'); s.className = 'insignia'; s.textContent = 'retirada'; t.append(' ', s); }
      celda(tr, f.sala);
      celda(tr, f.fecha);
      celda(tr, f.boletos + ' / ' + f.capacidad, 'num');
      var pct = Math.round(100 * f.boletos / Math.max(1, f.capacidad));
      var td = celda(tr, '');
      td.append(barra(pct, 'barra-ocup'), ' ' + pct + '%');
      celda(tr, f.recaudado, 'num');
      tbody.appendChild(tr);
    });

    listaPelis.replaceChildren();
    d.peliculas.forEach(function (p) {
      var li = document.createElement('li');
      var n = document.createElement('span'); n.className = 'bh-nombre'; n.textContent = p.titulo;
      var v = document.createElement('span'); v.className = 'bh-valor'; v.textContent = p.recaudado + ' · ' + p.boletos + ' bol.';
      li.append(n, barra(p.pct, 'bh-barra'), v);
      listaPelis.appendChild(li);
    });
    estado.classList.remove('sin-conexion');
  }

  function consultar() {
    fetch(api, { credentials: 'same-origin', cache: 'no-store', headers: { 'Accept': 'application/json' } })
      .then(function (r) { if (!r.ok) { throw new Error(r.status); } return r.json(); })
      .then(pintar)
      .catch(function () { estado.classList.add('sin-conexion'); });
  }
  setInterval(consultar, 5000);
})();
