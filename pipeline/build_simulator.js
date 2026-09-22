const fs = require('fs');
const path = require('path');

const linesData = JSON.parse(fs.readFileSync(path.join(__dirname, 'temp_pages_data.json'), 'utf8'));
const ayahsData = JSON.parse(fs.readFileSync(path.join(__dirname, 'temp_ayahs_data.json'), 'utf8'));
const transData = JSON.parse(fs.readFileSync(path.join(__dirname, 'temp_trans_data.json'), 'utf8'));
const surahsData = JSON.parse(fs.readFileSync(path.join(__dirname, 'temp_surahs_data.json'), 'utf8'));

const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>13-Line Quran Interactive Simulator</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Amiri+Quran&family=Amiri:ital,wght@0,400;0,700;1,400&family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;1,6..72,400&family=Noto+Naskh+Arabic:wght@400;600;700&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200" rel="stylesheet" />
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    :root {
      --bg-chassis: #E8E1D3;
      --bg-canvas: #F3EDE0;
      --bg-paper: #FAF6EE;
      --text-ink: #2B2620;
      --color-muted: #6E6459;
      --color-amber: #9E6B38;
      --border-sepia: #DFD7C7;
      --highlight-bg: rgba(212, 160, 84, 0.28);
      --highlight-border: #9E6B38;
    }
    [data-theme="ivory"] {
      --bg-chassis: #EDE9E0;
      --bg-canvas: #F7F4EC;
      --bg-paper: #FCFAF5;
      --text-ink: #262422;
      --color-muted: #73695E;
      --color-amber: #A6743A;
      --border-sepia: #E2DBD0;
      --highlight-bg: rgba(210, 165, 90, 0.25);
      --highlight-border: #A6743A;
    }
    [data-theme="dark"] {
      --bg-chassis: #121212;
      --bg-canvas: #000000;
      --bg-paper: #0D0D0D;
      --text-ink: #F5EBD7;
      --color-muted: #9E9486;
      --color-amber: #D4A054;
      --border-sepia: #262420;
      --highlight-bg: rgba(212, 160, 84, 0.32);
      --highlight-border: #D4A054;
    }

    body {
      background-color: var(--bg-chassis);
      color: var(--text-ink);
      font-family: 'Source Sans 3', -apple-system, sans-serif;
      user-select: none;
      transition: background-color 0.3s ease, color 0.3s ease;
    }

    .font-arabic {
      font-family: 'Amiri Quran', 'Amiri', 'Noto Naskh Arabic', serif;
      direction: rtl;
    }

    .font-serif-sub {
      font-family: 'Newsreader', serif;
    }

    .ayah-word {
      transition: background-color 0.15s ease, color 0.15s ease;
      cursor: pointer;
      border-radius: 4px;
      padding: 0 2px;
    }

    .ayah-word:hover {
      background-color: rgba(158, 107, 56, 0.15);
    }

    .ayah-word.active-ayah {
      background-color: var(--highlight-bg) !important;
      color: var(--text-ink) !important;
      box-shadow: 0 0 0 2px var(--highlight-border);
    }

    /* Spring touch response */
    .spring-press:active {
      transform: scale(0.95);
      transition: transform 0.12s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    }

    /* Soundwave animation */
    @keyframes waveBar {
      0%, 100% { height: 4px; }
      50% { height: 16px; }
    }
    .wave-bar-1 { animation: waveBar 0.8s ease-in-out infinite 0.1s; }
    .wave-bar-2 { animation: waveBar 0.8s ease-in-out infinite 0.3s; }
    .wave-bar-3 { animation: waveBar 0.8s ease-in-out infinite 0.5s; }
  </style>
</head>
<body class="min-h-screen flex flex-col items-center justify-center p-2 sm:p-6" data-theme="sepia">

  <!-- TOP APP CONTROLS -->
  <header class="w-full max-w-md mb-3 flex items-center justify-between px-2 text-xs font-medium text-stone-600">
    <div class="flex items-center gap-2">
      <span class="inline-block w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse"></span>
      <span class="font-semibold text-stone-800">13-Line Quran Simulator</span>
      <span class="bg-stone-300/60 px-1.5 py-0.5 rounded text-[10px]">iOS 17+ Swift 6 Mirror</span>
    </div>
    <div class="flex items-center gap-1.5">
      <button onclick="toggleTheme()" class="spring-press px-2.5 py-1 rounded-full bg-stone-200 hover:bg-stone-300 font-semibold flex items-center gap-1 text-stone-800 shadow-sm border border-stone-300">
        <span class="material-symbols-outlined text-sm">palette</span>
        <span id="themeLabel">Sepia</span>
      </button>
    </div>
  </header>

  <!-- iPHONE 16 PRO FRAME -->
  <main class="relative w-full max-w-[400px] h-[820px] rounded-[48px] shadow-[0_25px_60px_-15px_rgba(0,0,0,0.35),0_0_0_12px_#1E1C1A,0_0_0_14px_#3A3734] overflow-hidden flex flex-col border border-stone-700/30" style="background-color: var(--bg-canvas);">

    <!-- DYNAMIC ISLAND & STATUS BAR -->
    <div class="w-full pt-3 px-7 pb-1 flex justify-between items-center text-[12px] font-semibold tracking-tight z-30" style="color: var(--text-ink);">
      <span>9:41</span>
      <div class="w-28 h-6 bg-black rounded-full flex items-center justify-center px-2.5 gap-1.5 shadow-sm">
        <div id="dynamicIslandEqualizer" class="hidden items-center gap-0.5 h-3">
          <div class="w-0.5 bg-amber-400 wave-bar-1"></div>
          <div class="w-0.5 bg-amber-400 wave-bar-2"></div>
          <div class="w-0.5 bg-amber-400 wave-bar-3"></div>
        </div>
        <span class="text-[10px] text-stone-300 truncate" id="islandText">Sheikh Khalifa</span>
      </div>
      <div class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-[14px]">signal_cellular_4_bar</span>
        <span class="material-symbols-outlined text-[14px]">wifi</span>
        <span class="material-symbols-outlined text-[16px]">battery_full</span>
      </div>
    </div>

    <!-- TOP CHROME BAR -->
    <nav class="px-4 py-2 border-b flex items-center justify-between z-20" style="border-color: var(--border-sepia); background-color: var(--bg-canvas);">
      <div class="flex items-center gap-2">
        <button onclick="openTab('index')" class="spring-press p-1.5 rounded-lg border flex items-center justify-center text-stone-700" style="border-color: var(--border-sepia); color: var(--text-ink);" title="Surah / Juz Index">
          <span class="material-symbols-outlined text-[18px]">menu_book</span>
        </button>
        <div>
          <div class="text-[13px] font-bold leading-tight" id="headerSurahName" style="color: var(--text-ink);">Surah Al-Fatihah</div>
          <div class="text-[10px] font-medium" id="headerJuzInfo" style="color: var(--color-muted);">Juz 1 • Page 1 of 849</div>
        </div>
      </div>

      <!-- Quick Audio Pill & Bookmark -->
      <div class="flex items-center gap-1.5">
        <button onclick="toggleAudioPlayback()" id="audioPlayBtn" class="spring-press px-2.5 py-1 rounded-full flex items-center gap-1 text-[11px] font-bold text-white shadow-sm" style="background-color: var(--color-amber);">
          <span class="material-symbols-outlined text-[14px]" id="playIcon">play_arrow</span>
          <span id="playBtnText">Recite</span>
        </button>
        <button onclick="toggleBookmarkCurrentPage()" class="spring-press p-1.5 rounded-lg border text-stone-700" style="border-color: var(--border-sepia); color: var(--text-ink);" title="Bookmark Page">
          <span class="material-symbols-outlined text-[18px]" id="pageBookmarkIcon">bookmark_border</span>
        </button>
      </div>
    </nav>

    <!-- CONTENT VIEWS CONTAINER -->
    <div class="relative flex-1 overflow-hidden">

      <!-- VIEW 1: 13-LINE MUSHAF READER -->
      <div id="readerView" class="h-full flex flex-col">
        <!-- 13-LINE SACRED CANVAS -->
        <div class="flex-1 px-3 py-2 overflow-y-auto flex flex-col justify-between" style="background-color: var(--bg-paper);">
          <div id="linesContainer" class="flex flex-col justify-between h-full py-1 space-y-0.5">
            <!-- Rendered by JS: 13 exact physical lines -->
          </div>
        </div>

        <!-- BOTTOM PAGE NAVIGATION BAR -->
        <div class="px-4 py-2 border-t flex items-center justify-between text-xs" style="border-color: var(--border-sepia); background-color: var(--bg-canvas);">
          <button onclick="prevPage()" class="spring-press flex items-center gap-1 font-semibold px-2 py-1 rounded" style="color: var(--color-amber);">
            <span class="material-symbols-outlined text-[16px]">chevron_left</span> Prev
          </button>
          <div class="flex items-center gap-2">
            <span class="text-[11px] font-semibold" style="color: var(--text-ink);">Page</span>
            <select id="pageSelect" onchange="jumpToPage(parseInt(this.value))" class="text-xs font-bold rounded px-2 py-1 border bg-transparent" style="border-color: var(--border-sepia); color: var(--text-ink);">
              <option value="1">1 - Al-Fatihah</option>
              <option value="2">2 - Al-Baqarah</option>
              <option value="849">849 - An-Nas</option>
            </select>
          </div>
          <button onclick="nextPage()" class="spring-press flex items-center gap-1 font-semibold px-2 py-1 rounded" style="color: var(--color-amber);">
            Next <span class="material-symbols-outlined text-[16px]">chevron_right</span>
          </button>
        </div>
      </div>

      <!-- VIEW 2: INDEX HUB (SURAHS & JUZS) -->
      <div id="indexView" class="hidden h-full flex flex-col p-4 overflow-y-auto" style="background-color: var(--bg-canvas);">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-base font-bold" style="color: var(--text-ink);">Quran Index Hub</h2>
          <button onclick="openTab('reader')" class="material-symbols-outlined text-stone-500 hover:text-stone-800">close</button>
        </div>
        <div class="flex gap-2 mb-3">
          <button id="tabSurahsBtn" onclick="switchIndexTab('surahs')" class="flex-1 py-1.5 font-bold rounded-lg text-xs bg-amber-700 text-white">Surahs (114)</button>
          <button id="tabJuzsBtn" onclick="switchIndexTab('juzs')" class="flex-1 py-1.5 font-bold rounded-lg text-xs border" style="border-color: var(--border-sepia); color: var(--text-ink);">Juzs (30)</button>
        </div>
        <div id="surahsList" class="space-y-1.5 text-xs">
          <!-- Surahs list injected here -->
        </div>
        <div id="juzsList" class="hidden space-y-1.5 text-xs">
          <!-- Juzs list injected here -->
        </div>
      </div>

      <!-- VIEW 3: BOOKMARKS -->
      <div id="bookmarksView" class="hidden h-full flex flex-col p-4 overflow-y-auto" style="background-color: var(--bg-canvas);">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-base font-bold" style="color: var(--text-ink);">Saved Bookmarks</h2>
          <button onclick="openTab('reader')" class="material-symbols-outlined text-stone-500 hover:text-stone-800">close</button>
        </div>
        <div id="bookmarksContent" class="space-y-2 text-xs">
          <div class="p-4 rounded-xl border text-center text-stone-500" style="border-color: var(--border-sepia);">
            No bookmarks yet. Tap any verse or the bookmark button to save!
          </div>
        </div>
      </div>

      <!-- VIEW 4: SETTINGS -->
      <div id="settingsView" class="hidden h-full flex flex-col p-4 overflow-y-auto" style="background-color: var(--bg-canvas);">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-base font-bold" style="color: var(--text-ink);">Settings & Attributions</h2>
          <button onclick="openTab('reader')" class="material-symbols-outlined text-stone-500 hover:text-stone-800">close</button>
        </div>
        <div class="space-y-3 text-xs">
          <div class="p-3 rounded-xl border" style="border-color: var(--border-sepia);">
            <div class="font-bold mb-2" style="color: var(--text-ink);">Reading Theme</div>
            <div class="grid grid-cols-3 gap-2">
              <button onclick="setTheme('sepia')" class="p-2 rounded-lg border text-center font-bold bg-[#FAF6EE] text-[#2B2620] border-[#DFD7C7]">Sepia</button>
              <button onclick="setTheme('ivory')" class="p-2 rounded-lg border text-center font-bold bg-[#FCFAF5] text-[#262422] border-[#E2DBD0]">Ivory</button>
              <button onclick="setTheme('dark')" class="p-2 rounded-lg border text-center font-bold bg-[#0D0D0D] text-[#F5EBD7] border-[#262420]">Dark</button>
            </div>
          </div>
          <div class="p-3 rounded-xl border space-y-1.5" style="border-color: var(--border-sepia);">
            <div class="font-bold" style="color: var(--text-ink);">Reciter & Audio CDN</div>
            <div style="color: var(--color-muted);">Sheikh Khalifa Al Tunaiji (Hafs 'an 'Asim) streamed live from EveryAyah 64kbps.</div>
          </div>
          <div class="p-3 rounded-xl border bg-amber-500/10 border-amber-500/30 text-center space-y-1">
            <div class="font-bold text-amber-700">Sadaqah Jariyah</div>
            <div class="text-[11px]" style="color: var(--color-muted);">100% Free • No Ads • Zero Subscriptions forever.</div>
          </div>
        </div>
      </div>

    </div>

    <!-- NATIVE TAB BAR -->
    <div class="px-6 py-2 border-t flex items-center justify-around z-20" style="border-color: var(--border-sepia); background-color: var(--bg-canvas);">
      <button onclick="openTab('reader')" class="flex flex-col items-center gap-0.5 text-stone-600" id="navReadBtn">
        <span class="material-symbols-outlined text-[20px]">auto_stories</span>
        <span class="text-[10px] font-semibold">Read</span>
      </button>
      <button onclick="openTab('index')" class="flex flex-col items-center gap-0.5 text-stone-600" id="navIndexBtn">
        <span class="material-symbols-outlined text-[20px]">format_list_bulleted</span>
        <span class="text-[10px] font-semibold">Index</span>
      </button>
      <button onclick="openTab('bookmarks')" class="flex flex-col items-center gap-0.5 text-stone-600" id="navBookmarksBtn">
        <span class="material-symbols-outlined text-[20px]">bookmark</span>
        <span class="text-[10px] font-semibold">Saved</span>
      </button>
      <button onclick="openTab('settings')" class="flex flex-col items-center gap-0.5 text-stone-600" id="navSettingsBtn">
        <span class="material-symbols-outlined text-[20px]">settings</span>
        <span class="text-[10px] font-semibold">Settings</span>
      </button>
    </div>

    <!-- BOTTOM ACTION SHEET MODAL (AYAH SELECTION) -->
    <div id="actionSheetBackdrop" onclick="closeActionSheet()" class="hidden absolute inset-0 bg-black/40 z-40 transition-opacity"></div>
    <div id="actionSheet" class="absolute bottom-0 left-0 right-0 max-h-[75%] rounded-t-[32px] p-5 shadow-2xl z-50 transform translate-y-full transition-transform duration-300 ease-out flex flex-col border-t" style="background-color: var(--bg-canvas); border-color: var(--border-sepia);">
      <!-- Pull handle -->
      <div class="w-10 h-1 rounded-full bg-stone-400/50 mx-auto mb-3"></div>

      <div class="flex items-center justify-between pb-2 border-b" style="border-color: var(--border-sepia);">
        <div>
          <div class="text-sm font-bold" id="sheetAyahTitle" style="color: var(--text-ink);">Surah Al-Fatihah, Ayah 1</div>
          <div class="text-[11px]" id="sheetAyahMeta" style="color: var(--color-muted);">Page 1 • Juz 1</div>
        </div>
        <button onclick="closeActionSheet()" class="material-symbols-outlined text-stone-500 hover:text-stone-800">cancel</button>
      </div>

      <!-- Arabic & Translation Content -->
      <div class="my-3 space-y-2 overflow-y-auto max-h-[220px] pr-1">
        <div class="font-arabic text-xl leading-loose text-right" id="sheetArabicText" style="color: var(--text-ink);">
          بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ۝١
        </div>
        <div class="flex items-center justify-between">
          <select id="authorSelect" onchange="updateTranslationText()" class="text-[11px] font-bold rounded px-2 py-1 border bg-transparent" style="border-color: var(--border-sepia); color: var(--color-amber);">
            <option value="saheeh">Saheeh International (EN)</option>
            <option value="hilali_khan">Dr. Hilali & Dr. Khan (EN)</option>
            <option value="hamidullah">Dr. Hamidullah (FR)</option>
          </select>
          <span id="copiedBadge" class="hidden text-[10px] font-bold text-amber-600 bg-amber-100 px-2 py-0.5 rounded-full">Copied!</span>
        </div>
        <div class="font-serif-sub text-xs leading-relaxed" id="sheetTransText" style="color: var(--text-ink);">
          In the name of Allah, the Entirely Merciful, the Especially Merciful.
        </div>
      </div>

      <!-- 4 Action Buttons -->
      <div class="grid grid-cols-4 gap-2 pt-2 border-t" style="border-color: var(--border-sepia);">
        <button onclick="playSheetAyah()" class="spring-press p-2 rounded-xl border flex flex-col items-center gap-1 font-bold text-[11px]" style="border-color: var(--border-sepia); color: var(--text-ink); background-color: var(--bg-paper);">
          <span class="material-symbols-outlined text-[20px]" style="color: var(--color-amber);">play_circle</span> Play
        </button>
        <button onclick="toggleSheetBookmark()" id="sheetBookmarkBtn" class="spring-press p-2 rounded-xl border flex flex-col items-center gap-1 font-bold text-[11px]" style="border-color: var(--border-sepia); color: var(--text-ink); background-color: var(--bg-paper);">
          <span class="material-symbols-outlined text-[20px]" style="color: var(--color-amber);">bookmark</span> Bookmark
        </button>
        <button onclick="copySheetVerse()" class="spring-press p-2 rounded-xl border flex flex-col items-center gap-1 font-bold text-[11px]" style="border-color: var(--border-sepia); color: var(--text-ink); background-color: var(--bg-paper);">
          <span class="material-symbols-outlined text-[20px]" style="color: var(--color-amber);">content_copy</span> Copy
        </button>
        <button onclick="shareSheetVerse()" class="spring-press p-2 rounded-xl border flex flex-col items-center gap-1 font-bold text-[11px]" style="border-color: var(--border-sepia); color: var(--text-ink); background-color: var(--bg-paper);">
          <span class="material-symbols-outlined text-[20px]" style="color: var(--color-amber);">share</span> Share
        </button>
      </div>

      <!-- Memorization Repeat Selector -->
      <div class="mt-3 pt-2 border-t flex items-center justify-between text-xs" style="border-color: var(--border-sepia);">
        <span class="text-[11px] font-semibold" style="color: var(--color-muted);">Hifdh Repeat:</span>
        <div class="flex gap-1.5">
          <button onclick="setRepeatCount(1)" id="repeatBtn1" class="px-2 py-0.5 rounded font-bold bg-amber-700 text-white">1×</button>
          <button onclick="setRepeatCount(3)" id="repeatBtn3" class="px-2 py-0.5 rounded font-bold border" style="border-color: var(--border-sepia); color: var(--text-ink);">3×</button>
          <button onclick="setRepeatCount(5)" id="repeatBtn5" class="px-2 py-0.5 rounded font-bold border" style="border-color: var(--border-sepia); color: var(--text-ink);">5×</button>
          <button onclick="setRepeatCount(10)" id="repeatBtn10" class="px-2 py-0.5 rounded font-bold border" style="border-color: var(--border-sepia); color: var(--text-ink);">10×</button>
        </div>
      </div>
    </div>

  </main>

  <!-- HIDDEN AUDIO ENGINE -->
  <audio id="quranAudio" preload="auto"></audio>

  <!-- DATA & LOGIC SCRIPT -->
  <script>
    // Injected SQLite Data
    const LINES_DATA = ${JSON.stringify(linesData)};
    const AYAHS_DATA = ${JSON.stringify(ayahsData)};
    const TRANS_DATA = ${JSON.stringify(transData)};
    const SURAHS_DATA = ${JSON.stringify(surahsData)};

    let currentPage = 1;
    let selectedAyah = null;
    let currentTheme = 'sepia';
    let isPlaying = false;
    let playingAyah = null;
    let repeatTarget = 1;
    let repeatCurrent = 1;
    let bookmarks = JSON.parse(localStorage.getItem('mushaf_bookmarks') || '[]');

    const audio = document.getElementById('quranAudio');

    function init() {
      renderPage(currentPage);
      renderSurahsList();
      renderJuzsList();
      updateBookmarksUI();
      setupAudioListeners();
      updateNavStyles('reader');
    }

    function renderPage(pageNum) {
      currentPage = pageNum;
      document.getElementById('pageSelect').value = pageNum;
      
      const pageLines = LINES_DATA.filter(l => l.page_number === pageNum).sort((a,b) => a.line_number - b.line_number);
      const container = document.getElementById('linesContainer');
      container.innerHTML = '';

      // Update Top Chrome Info
      if (pageNum === 1) {
        document.getElementById('headerSurahName').innerText = 'Surah Al-Fatihah';
        document.getElementById('headerJuzInfo').innerText = 'Juz 1 • Page 1 of 849';
      } else if (pageNum === 2) {
        document.getElementById('headerSurahName').innerText = 'Surah Al-Baqarah';
        document.getElementById('headerJuzInfo').innerText = 'Juz 1 • Page 2 of 849';
      } else if (pageNum === 849) {
        document.getElementById('headerSurahName').innerText = 'Surah An-Nas';
        document.getElementById('headerJuzInfo').innerText = 'Juz 30 • Page 849 of 849';
      }

      // Check if page bookmarked
      const isPageBm = bookmarks.some(b => b.type === 'page' && b.pageNumber === pageNum);
      document.getElementById('pageBookmarkIcon').innerText = isPageBm ? 'bookmark' : 'bookmark_border';
      document.getElementById('pageBookmarkIcon').style.color = isPageBm ? 'var(--color-amber)' : 'inherit';

      pageLines.forEach(l => {
        const lineDiv = document.createElement('div');
        lineDiv.className = 'w-full flex items-center justify-center font-arabic leading-none px-1 text-center';
        lineDiv.style.minHeight = '32px';

        if (l.line_type === 'surah_name') {
          lineDiv.className += ' py-1';
          lineDiv.innerHTML = \`
            <div class="w-full border-2 rounded-lg py-1 px-3 text-center font-bold text-sm tracking-wider shadow-sm flex items-center justify-between" style="border-color: var(--color-amber); background-color: var(--bg-canvas); color: var(--text-ink);">
              <span class="text-[10px] font-serif-sub font-semibold" style="color: var(--color-muted);">سُورَة</span>
              <span class="text-base font-bold">\${l.text_indopak || 'سُورَة'}</span>
              <span class="text-[10px] font-serif-sub font-semibold" style="color: var(--color-muted);">7 آيات</span>
            </div>
          \`;
        } else if (l.line_type === 'bismillah') {
          lineDiv.className += ' py-0.5 text-base';
          lineDiv.style.color = 'var(--text-ink)';
          lineDiv.innerHTML = \`<span class="tracking-wide">﷽</span>\`;
        } else {
          // Regular line with word tokens
          lineDiv.className += ' justify-between text-[17px]';
          const words = JSON.parse(l.words_json || '[]');
          
          let lineHtml = '';
          words.forEach(w => {
            const isAyahMarker = w.text.includes('۝') || /^[\\d\\u0660-\\u0669]+$/.test(w.text);
            const activeClass = (selectedAyah && selectedAyah.surah === w.surah && selectedAyah.ayah === w.ayah) ? 'active-ayah' : '';
            const playingClass = (playingAyah && playingAyah.surah === w.surah && playingAyah.ayah === w.ayah) ? 'active-ayah' : '';
            
            lineHtml += \`
              <span class="ayah-word \${activeClass} \${playingClass}" 
                    data-surah="\${w.surah}" 
                    data-ayah="\${w.ayah}" 
                    onclick="selectAyah(\${w.surah}, \${w.ayah})">
                \${w.text}
              </span>
            \`;
          });
          lineDiv.innerHTML = lineHtml;
        }

        container.appendChild(lineDiv);
      });
    }

    function selectAyah(surah, ayah) {
      selectedAyah = { surah, ayah };
      highlightActiveAyah();
      openActionSheet(surah, ayah);
    }

    function highlightActiveAyah() {
      document.querySelectorAll('.ayah-word').forEach(el => {
        const s = parseInt(el.getAttribute('data-surah'));
        const a = parseInt(el.getAttribute('data-ayah'));
        const isSel = selectedAyah && selectedAyah.surah === s && selectedAyah.ayah === a;
        const isPly = playingAyah && playingAyah.surah === s && playingAyah.ayah === a;
        if (isSel || isPly) {
          el.classList.add('active-ayah');
        } else {
          el.classList.remove('active-ayah');
        }
      });
    }

    function openActionSheet(surah, ayah) {
      const ayahRecord = AYAHS_DATA.find(a => a.surah_id === surah && a.verse_number === ayah);
      if (!ayahRecord) return;

      document.getElementById('sheetAyahTitle').innerText = \`Surah \${surah}, Ayah \${ayah}\`;
      document.getElementById('sheetAyahMeta').innerText = \`Page \${ayahRecord.page_number} • Global Verse #\${ayahRecord.id}\`;
      document.getElementById('sheetArabicText').innerText = ayahRecord.text_indopak;

      updateTranslationText();

      // Bookmark button state
      const isBm = bookmarks.some(b => b.type === 'ayah' && b.surahId === surah && b.verseNumber === ayah);
      const bmBtn = document.getElementById('sheetBookmarkBtn');
      bmBtn.querySelector('.material-symbols-outlined').innerText = isBm ? 'bookmark_added' : 'bookmark';
      bmBtn.style.color = isBm ? 'var(--color-amber)' : 'inherit';

      document.getElementById('actionSheetBackdrop').classList.remove('hidden');
      document.getElementById('actionSheet').classList.remove('translate-y-full');
    }

    function closeActionSheet() {
      document.getElementById('actionSheetBackdrop').classList.add('hidden');
      document.getElementById('actionSheet').classList.add('translate-y-full');
    }

    function updateTranslationText() {
      if (!selectedAyah) return;
      const ayahRecord = AYAHS_DATA.find(a => a.surah_id === selectedAyah.surah && a.verse_number === selectedAyah.ayah);
      if (!ayahRecord) return;

      const author = document.getElementById('authorSelect').value;
      const trans = TRANS_DATA.find(t => t.ayah_id === ayahRecord.id && t.author_code === author);
      document.getElementById('sheetTransText').innerText = trans ? trans.text : 'Translation loading...';
    }

    // AUDIO PLAYBACK ENGINE (EVERYAYAH STREAM)
    function setupAudioListeners() {
      audio.addEventListener('play', () => {
        isPlaying = true;
        document.getElementById('playIcon').innerText = 'pause';
        document.getElementById('playBtnText').innerText = 'Playing';
        document.getElementById('dynamicIslandEqualizer').classList.remove('hidden');
        document.getElementById('dynamicIslandEqualizer').classList.add('flex');
      });

      audio.addEventListener('pause', () => {
        isPlaying = false;
        document.getElementById('playIcon').innerText = 'play_arrow';
        document.getElementById('playBtnText').innerText = 'Recite';
        document.getElementById('dynamicIslandEqualizer').classList.add('hidden');
        document.getElementById('dynamicIslandEqualizer').classList.remove('flex');
      });

      audio.addEventListener('ended', () => {
        if (repeatCurrent < repeatTarget) {
          repeatCurrent++;
          audio.currentTime = 0;
          audio.play();
        } else {
          repeatCurrent = 1;
          autoAdvanceNextAyah();
        }
      });
    }

    function playAyahAudio(surah, ayah) {
      playingAyah = { surah, ayah };
      highlightActiveAyah();

      const sPad = String(surah).padStart(3, '0');
      const aPad = String(ayah).padStart(3, '0');
      const cdnUrl = \`https://everyayah.com/data/khalefa_al_tunaiji_64kbps/\${sPad}\${aPad}.mp3\`;
      
      document.getElementById('islandText').innerText = \`Surah \${surah}:\${ayah}\`;
      audio.src = cdnUrl;
      audio.play().catch(e => console.log('Audio autoplay prevented by browser interaction policy'));
    }

    function toggleAudioPlayback() {
      if (isPlaying) {
        audio.pause();
      } else {
        if (playingAyah) {
          audio.play();
        } else {
          // Play first ayah of current page
          const firstAyah = AYAHS_DATA.find(a => a.page_number === currentPage);
          if (firstAyah) {
            playAyahAudio(firstAyah.surah_id, firstAyah.verse_number);
          }
        }
      }
    }

    function playSheetAyah() {
      if (selectedAyah) {
        repeatCurrent = 1;
        playAyahAudio(selectedAyah.surah, selectedAyah.ayah);
        closeActionSheet();
      }
    }

    function autoAdvanceNextAyah() {
      if (!playingAyah) return;
      const nextAyah = AYAHS_DATA.find(a => a.surah_id === playingAyah.surah && a.verse_number === playingAyah.ayah + 1);
      if (nextAyah) {
        if (nextAyah.page_number !== currentPage) {
          renderPage(nextAyah.page_number);
        }
        playAyahAudio(nextAyah.surah_id, nextAyah.verse_number);
      } else {
        isPlaying = false;
        playingAyah = null;
        highlightActiveAyah();
      }
    }

    function setRepeatCount(count) {
      repeatTarget = count;
      [1, 3, 5, 10].forEach(n => {
        const btn = document.getElementById('repeatBtn' + n);
        if (n === count) {
          btn.className = 'px-2 py-0.5 rounded font-bold bg-amber-700 text-white';
        } else {
          btn.className = 'px-2 py-0.5 rounded font-bold border';
          btn.style.borderColor = 'var(--border-sepia)';
          btn.style.color = 'var(--text-ink)';
        }
      });
    }

    // BOOKMARKS LOGIC
    function toggleBookmarkCurrentPage() {
      const idx = bookmarks.findIndex(b => b.type === 'page' && b.pageNumber === currentPage);
      if (idx >= 0) {
        bookmarks.splice(idx, 1);
      } else {
        bookmarks.push({ type: 'page', pageNumber: currentPage, date: new Date().toLocaleDateString() });
      }
      localStorage.setItem('mushaf_bookmarks', JSON.stringify(bookmarks));
      renderPage(currentPage);
      updateBookmarksUI();
    }

    function toggleSheetBookmark() {
      if (!selectedAyah) return;
      const { surah, ayah } = selectedAyah;
      const idx = bookmarks.findIndex(b => b.type === 'ayah' && b.surahId === surah && b.verseNumber === ayah);
      if (idx >= 0) {
        bookmarks.splice(idx, 1);
      } else {
        bookmarks.push({ type: 'ayah', surahId: surah, verseNumber: ayah, pageNumber: currentPage, date: new Date().toLocaleDateString() });
      }
      localStorage.setItem('mushaf_bookmarks', JSON.stringify(bookmarks));
      openActionSheet(surah, ayah);
      updateBookmarksUI();
    }

    function updateBookmarksUI() {
      const container = document.getElementById('bookmarksContent');
      if (bookmarks.length === 0) {
        container.innerHTML = '<div class="p-4 rounded-xl border text-center text-stone-500" style="border-color: var(--border-sepia);">No bookmarks saved yet.</div>';
        return;
      }
      container.innerHTML = '';
      bookmarks.forEach(b => {
        const item = document.createElement('div');
        item.className = 'p-3 rounded-xl border flex items-center justify-between';
        item.style.borderColor = 'var(--border-sepia)';
        item.style.backgroundColor = 'var(--bg-paper)';
        
        if (b.type === 'page') {
          item.innerHTML = \`
            <div>
              <div class="font-bold" style="color: var(--text-ink);">Page \${b.pageNumber}</div>
              <div class="text-[10px]" style="color: var(--color-muted);">Saved on \${b.date}</div>
            </div>
            <button onclick="jumpToPage(\${b.pageNumber}); openTab('reader')" class="px-2.5 py-1 rounded bg-amber-700 text-white font-bold">Open</button>
          \`;
        } else {
          item.innerHTML = \`
            <div>
              <div class="font-bold" style="color: var(--text-ink);">Surah \${b.surahId}, Ayah \${b.verseNumber}</div>
              <div class="text-[10px]" style="color: var(--color-muted);">Page \${b.pageNumber} • Saved on \${b.date}</div>
            </div>
            <button onclick="jumpToPage(\${b.pageNumber}); selectAyah(\${b.surahId}, \${b.verseNumber}); openTab('reader')" class="px-2.5 py-1 rounded bg-amber-700 text-white font-bold">Open</button>
          \`;
        }
        container.appendChild(item);
      });
    }

    function copySheetVerse() {
      if (!selectedAyah) return;
      const ayahRecord = AYAHS_DATA.find(a => a.surah_id === selectedAyah.surah && a.verse_number === selectedAyah.ayah);
      const transText = document.getElementById('sheetTransText').innerText;
      const textToCopy = \`\${ayahRecord.text_indopak}\\n\\n\${transText}\\n— [Surah \${selectedAyah.surah}:\${selectedAyah.ayah}]\`;
      
      navigator.clipboard.writeText(textToCopy).then(() => {
        const badge = document.getElementById('copiedBadge');
        badge.classList.remove('hidden');
        setTimeout(() => badge.classList.add('hidden'), 2000);
      });
    }

    function shareSheetVerse() {
      if (navigator.share && selectedAyah) {
        const ayahRecord = AYAHS_DATA.find(a => a.surah_id === selectedAyah.surah && a.verse_number === selectedAyah.ayah);
        navigator.share({
          title: \`Surah \${selectedAyah.surah}:\${selectedAyah.ayah}\`,
          text: \`\${ayahRecord.text_indopak}\\n\\n\${document.getElementById('sheetTransText').innerText}\`
        }).catch(() => {});
      } else {
        copySheetVerse();
      }
    }

    // THEMES
    function setTheme(theme) {
      currentTheme = theme;
      document.body.setAttribute('data-theme', theme);
      document.getElementById('themeLabel').innerText = theme.charAt(0).toUpperCase() + theme.slice(1);
    }

    function toggleTheme() {
      const themes = ['sepia', 'ivory', 'dark'];
      const next = themes[(themes.indexOf(currentTheme) + 1) % themes.length];
      setTheme(next);
    }

    // NAVIGATION TABS
    function openTab(tab) {
      ['reader', 'index', 'bookmarks', 'settings'].forEach(t => {
        document.getElementById(t + 'View').classList.add('hidden');
      });
      document.getElementById(tab + 'View').classList.remove('hidden');
      updateNavStyles(tab);
    }

    function updateNavStyles(activeTab) {
      ['Read', 'Index', 'Bookmarks', 'Settings'].forEach(name => {
        const btn = document.getElementById('nav' + name + 'Btn');
        const isActive = name.toLowerCase().startsWith(activeTab.substring(0, 4));
        btn.style.color = isActive ? 'var(--color-amber)' : 'inherit';
      });
    }

    function switchIndexTab(type) {
      if (type === 'surahs') {
        document.getElementById('surahsList').classList.remove('hidden');
        document.getElementById('juzsList').classList.add('hidden');
        document.getElementById('tabSurahsBtn').className = 'flex-1 py-1.5 font-bold rounded-lg text-xs bg-amber-700 text-white';
        document.getElementById('tabJuzsBtn').className = 'flex-1 py-1.5 font-bold rounded-lg text-xs border text-stone-700';
      } else {
        document.getElementById('surahsList').classList.add('hidden');
        document.getElementById('juzsList').classList.remove('hidden');
        document.getElementById('tabJuzsBtn').className = 'flex-1 py-1.5 font-bold rounded-lg text-xs bg-amber-700 text-white';
        document.getElementById('tabSurahsBtn').className = 'flex-1 py-1.5 font-bold rounded-lg text-xs border text-stone-700';
      }
    }

    function renderSurahsList() {
      const list = document.getElementById('surahsList');
      list.innerHTML = '';
      SURAHS_DATA.forEach(s => {
        const row = document.createElement('div');
        row.className = 'p-2.5 rounded-lg border flex items-center justify-between cursor-pointer hover:bg-stone-100 dark:hover:bg-stone-900';
        row.style.borderColor = 'var(--border-sepia)';
        row.innerHTML = \`
          <div class="flex items-center gap-2">
            <span class="w-6 h-6 rounded-full bg-amber-500/20 text-amber-800 font-bold flex items-center justify-center text-[10px]">\${s.id}</span>
            <div>
              <div class="font-bold" style="color: var(--text-ink);">\${s.english_name}</div>
              <div class="text-[10px]" style="color: var(--color-muted);">\${s.total_verses} Verses • Page \${s.start_page}</div>
            </div>
          </div>
          <div class="font-arabic text-sm font-bold" style="color: var(--color-amber);">\${s.arabic_name}</div>
        \`;
        row.onclick = () => {
          if ([1, 2, 849].includes(s.start_page)) {
            jumpToPage(s.start_page);
          } else {
            jumpToPage(1);
          }
          openTab('reader');
        };
        list.appendChild(row);
      });
    }

    function renderJuzsList() {
      const list = document.getElementById('juzsList');
      list.innerHTML = '';
      const sampleJuzs = [
        { id: 1, name: 'Alif Lam Meem', page: 1 },
        { id: 2, name: 'Sayaqool', page: 22 },
        { id: 30, name: 'Amma Yatasa\'aloon', page: 818 }
      ];
      sampleJuzs.forEach(j => {
        const row = document.createElement('div');
        row.className = 'p-2.5 rounded-lg border flex items-center justify-between cursor-pointer hover:bg-stone-100 dark:hover:bg-stone-900';
        row.style.borderColor = 'var(--border-sepia)';
        row.innerHTML = \`
          <div class="flex items-center gap-2">
            <span class="w-6 h-6 rounded-full bg-amber-500/20 text-amber-800 font-bold flex items-center justify-center text-[10px]">\${j.id}</span>
            <div class="font-bold" style="color: var(--text-ink);">Juz \${j.id} (\${j.name})</div>
          </div>
          <span class="text-[11px] font-semibold" style="color: var(--color-muted);">p. \${j.page}</span>
        \`;
        row.onclick = () => {
          if (j.id === 30) jumpToPage(849);
          else jumpToPage(1);
          openTab('reader');
        };
        list.appendChild(row);
      });
    }

    function jumpToPage(p) {
      renderPage(p);
    }

    function prevPage() {
      if (currentPage === 849) jumpToPage(2);
      else if (currentPage === 2) jumpToPage(1);
    }

    function nextPage() {
      if (currentPage === 1) jumpToPage(2);
      else if (currentPage === 2) jumpToPage(849);
    }

    window.onload = init;
  </script>
</body>
</html>
`;

// Save in workspace root
fs.writeFileSync(path.join(__dirname, '..', 'web_simulator.html'), htmlContent, 'utf8');

// Save in artifact dir if environment variable is set
const artifactDir = process.env.ARTIFACT_DIR;
if (artifactDir && fs.existsSync(artifactDir)) {
  fs.writeFileSync(path.join(artifactDir, 'web_simulator.html'), htmlContent, 'utf8');
}

console.log('Successfully generated web_simulator.html!');
