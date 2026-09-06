<script>
document.addEventListener('DOMContentLoaded', function () {
  function menuLabel(link) {
    var clone = link.cloneNode(true);
    clone.querySelectorAll('.chapter-number, .header-section-number').forEach(function (number) {
      number.remove();
    });
    return clone.textContent.trim().replace(/\s+/g, ' ');
  }

  document.querySelectorAll('.sidebar-item-text[href="./index.html"], .sidebar-item-text[href="../index.html"]')
    .forEach(function (link) {
      link.classList.add('hi-index-link');
      var menuText = link.querySelector('.menu-text');
      if (menuText) {
        menuText.textContent = 'Inngangur';
      }
    });

  var activeLink = document.querySelector('.sidebar-item.active > .sidebar-item-container > a, .sidebar-item.active > a');
  if (!activeLink) return;

  var partTitle = '';
  var section = activeLink.closest('.sidebar-item-section');
  if (section) {
    var partLink = section.querySelector(':scope > .sidebar-item-container > .sidebar-item-text .menu-text');
    if (partLink) partTitle = menuLabel(partLink);
  }

  var chapterText = activeLink.querySelector('.menu-text');
  var chapterTitle = chapterText ? menuLabel(chapterText) : menuLabel(activeLink);

  if (!partTitle && !chapterTitle) return;

  var bar = document.createElement('div');
  bar.id = 'hi-breadcrumb';
  bar.setAttribute('aria-label', 'breadcrumb');

  if (partTitle && chapterTitle && partTitle !== chapterTitle) {
    bar.innerHTML =
      '<span class="hi-bc-part">' + partTitle + '</span>' +
      '<span class="hi-bc-sep" aria-hidden="true">›</span>' +
      '<span class="hi-bc-chapter">' + chapterTitle + '</span>';
  } else {
    bar.innerHTML = '<span class="hi-bc-chapter">' + (partTitle || chapterTitle) + '</span>';
  }

  var navbar = document.querySelector('nav.navbar');
  if (navbar && navbar.parentNode) {
    navbar.parentNode.insertBefore(bar, navbar.nextSibling);
  }
});
</script>
