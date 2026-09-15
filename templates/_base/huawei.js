// Huawei document templates — copy-to-clipboard for code blocks
(function() {
  'use strict';

  function addCopyButtons() {
    var pres = document.querySelectorAll('pre');
    pres.forEach(function(pre) {
      if (pre.querySelector('.copy-btn')) return; // already has button
      var btn = document.createElement('button');
      btn.className = 'copy-btn';
      btn.textContent = 'Copy';
      btn.type = 'button';
      btn.addEventListener('click', function() {
        var code = pre.querySelector('code');
        var text = code ? code.textContent : pre.textContent;
        navigator.clipboard.writeText(text).then(function() {
          btn.classList.add('copied');
          btn.textContent = 'Copied';
          setTimeout(function() {
            btn.classList.remove('copied');
            btn.textContent = 'Copy';
          }, 2000);
        }).catch(function() {
          // Fallback for older browsers
          var textarea = document.createElement('textarea');
          textarea.value = text;
          document.body.appendChild(textarea);
          textarea.select();
          try { document.execCommand('copy'); } catch(e) {}
          document.body.removeChild(textarea);
          btn.classList.add('copied');
          btn.textContent = 'Copied';
          setTimeout(function() {
            btn.classList.remove('copied');
            btn.textContent = 'Copy';
          }, 2000);
        });
      });
      pre.appendChild(btn);
    });
  }

  // Run on load and on DOM changes
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addCopyButtons);
  } else {
    addCopyButtons();
  }
})();
