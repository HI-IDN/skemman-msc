<style>
  .sortable table th {
    cursor: pointer;
    user-select: none;
    white-space: nowrap;
  }
  .sortable table th::after {
    content: " \2195";
    opacity: 0.25;
    font-size: 0.85em;
  }
  .sortable table th[data-sort="asc"]::after  { content: " \25B2"; opacity: 0.85; }
  .sortable table th[data-sort="desc"]::after { content: " \25BC"; opacity: 0.85; }
  .sortable table th:focus-visible { outline: 2px solid currentColor; outline-offset: -2px; }
</style>
<script>
// Smellanlegir dálkahausar á töflum inni í ::: {.sortable} blokk.
// Talnadálkar raðast tölulega, aðrir eftir íslenskri stafrófsröð.
document.addEventListener('DOMContentLoaded', function () {
  var toNumber = function (text) {
    // Þúsundapunktur/bil burt, íslensk tugakomma í punkt.
    var cleaned = text.replace(/[\s .]/g, '').replace(',', '.');
    return cleaned === '' ? NaN : Number(cleaned);
  };

  document.querySelectorAll('.sortable table').forEach(function (table) {
    var head = table.tHead;
    var body = table.tBodies[0];
    if (!head || !body || !head.rows.length) return;

    var headerRow = head.rows[head.rows.length - 1];

    Array.prototype.forEach.call(headerRow.cells, function (th, index) {
      th.tabIndex = 0;
      th.setAttribute('role', 'button');

      var sort = function () {
        var ascending = th.getAttribute('data-sort') !== 'asc';

        Array.prototype.forEach.call(headerRow.cells, function (other) {
          other.removeAttribute('data-sort');
          other.removeAttribute('aria-sort');
        });
        th.setAttribute('data-sort', ascending ? 'asc' : 'desc');
        th.setAttribute('aria-sort', ascending ? 'ascending' : 'descending');

        var rows = Array.prototype.slice.call(body.rows);
        rows.sort(function (a, b) {
          var x = a.cells[index] ? a.cells[index].textContent.trim() : '';
          var y = b.cells[index] ? b.cells[index].textContent.trim() : '';
          var nx = toNumber(x);
          var ny = toNumber(y);
          var result;
          if (!isNaN(nx) && !isNaN(ny)) {
            result = nx - ny;
          } else {
            result = x.localeCompare(y, 'is');
          }
          return ascending ? result : -result;
        });

        var frag = document.createDocumentFragment();
        rows.forEach(function (row) { frag.appendChild(row); });
        body.appendChild(frag);
      };

      th.addEventListener('click', sort);
      th.addEventListener('keydown', function (event) {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          sort();
        }
      });
    });
  });
});
</script>
