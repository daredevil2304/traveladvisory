const String routeRadarLogoSvg = r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" width="800" height="600">
  <defs>
    <!-- Crisp High-Contrast Luminous Ceramic Background Gradient -->
    <linearGradient id="lightBgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="45%" stop-color="#F8FAFC" />
      <stop offset="100%" stop-color="#E2E8F0" />
    </linearGradient>

    <!-- Radar Sweep Glow -->
    <radialGradient id="radarSweep" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#0284C7" stop-opacity="0.25" />
      <stop offset="70%" stop-color="#38BDF8" stop-opacity="0.10" />
      <stop offset="100%" stop-color="#38BDF8" stop-opacity="0" />
    </radialGradient>

    <!-- Deep Expressway Road Gradient -->
    <linearGradient id="roadGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1E293B" />
      <stop offset="100%" stop-color="#0F172A" />
    </linearGradient>

    <!-- Glowing Amber Beacon -->
    <radialGradient id="beaconGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="25%" stop-color="#FBBF24" />
      <stop offset="60%" stop-color="#F59E0B" stop-opacity="0.9" />
      <stop offset="100%" stop-color="#F59E0B" stop-opacity="0" />
    </radialGradient>

    <!-- Drop Shadow for High Contrast Pop -->
    <filter id="badgeShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="18" stdDeviation="28" flood-color="#0F172A" flood-opacity="0.22"/>
    </filter>
  </defs>

  <!-- Luminous Badge Outer Frame -->
  <rect x="28" y="28" width="744" height="544" rx="72" fill="url(#lightBgGrad)" stroke="#0284C7" stroke-width="4" stroke-opacity="0.85" filter="url(#badgeShadow)" />
  <rect x="34" y="34" width="732" height="532" rx="66" fill="none" stroke="#38BDF8" stroke-width="1.5" stroke-opacity="0.5" />

  <!-- Radar Horizon Field -->
  <circle cx="400" cy="205" r="215" fill="url(#radarSweep)" />

  <!-- Mountain Silhouette Backdrop (Western Ghats) -->
  <path d="M 60 330 Q 180 230 280 270 T 400 200 T 520 270 T 660 220 L 740 330 L 740 375 L 60 375 Z" fill="#CBD5E1" opacity="0.75" />
  <path d="M 60 350 Q 160 265 260 290 T 400 230 T 540 290 T 720 260 L 740 375 L 60 375 Z" fill="#94A3B8" opacity="0.65" />

  <!-- Radar Pulse Rings -->
  <circle cx="400" cy="205" r="195" fill="none" stroke="#0284C7" stroke-width="2" stroke-dasharray="8 6" stroke-opacity="0.45" />
  <circle cx="400" cy="205" r="135" fill="none" stroke="#0284C7" stroke-width="2.5" stroke-dasharray="10 8" stroke-opacity="0.65" />
  <circle cx="400" cy="205" r="75" fill="none" stroke="#0284C7" stroke-width="3" stroke-opacity="0.85" />

  <!-- Radar Sweep Arc Sector -->
  <path d="M 400 205 L 260 80 A 195 195 0 0 1 370 12 M 400 205 Z" fill="#0284C7" opacity="0.14" />

  <!-- Crosshair Reticles -->
  <line x1="205" y1="205" x2="595" y2="205" stroke="#0284C7" stroke-width="1.5" stroke-opacity="0.4" stroke-dasharray="6 6" />
  <line x1="400" y1="30" x2="400" y2="375" stroke="#0284C7" stroke-width="1.5" stroke-opacity="0.4" stroke-dasharray="6 6" />

  <!-- 3D Perspective Expressway -->
  <path d="M 270 375 L 391 205 L 409 205 L 530 375 Z" fill="url(#roadGradient)" />

  <!-- Glowing Road Curbs -->
  <line x1="270" y1="375" x2="391" y2="205" stroke="#0284C7" stroke-width="6" stroke-linecap="round" />
  <line x1="530" y1="375" x2="409" y2="205" stroke="#0284C7" stroke-width="6" stroke-linecap="round" />

  <!-- Golden Expressway Center Dash Markings -->
  <line x1="400" y1="215" x2="400" y2="235" stroke="#F59E0B" stroke-width="3.5" stroke-linecap="round" />
  <line x1="400" y1="250" x2="400" y2="280" stroke="#F59E0B" stroke-width="4.5" stroke-linecap="round" />
  <line x1="400" y1="300" x2="400" y2="340" stroke="#F59E0B" stroke-width="5.5" stroke-linecap="round" />
  <line x1="400" y1="355" x2="400" y2="375" stroke="#F59E0B" stroke-width="6.5" stroke-linecap="round" />

  <!-- Pulse Origin Beacon (Amber/Gold Glowing Core) -->
  <circle cx="400" cy="205" r="28" fill="url(#beaconGlow)" />
  <circle cx="400" cy="205" r="8" fill="#FFFFFF" stroke="#F59E0B" stroke-width="2.5" />

  <!-- Brand Typography (Deep Navy & Vibrant Cyan on Luminous White) -->
  <g text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif">
    <!-- Main App Name -->
    <text x="400" y="465" font-size="58" font-weight="900" letter-spacing="4">
      <tspan fill="#0F172A">ROUTE</tspan><tspan fill="#0284C7">RADAR</tspan>
    </text>

    <!-- Subtitle / Corridor Description -->
    <text x="400" y="505" font-size="16" font-weight="800" fill="#475569" letter-spacing="7">
      MUMBAI - PUNE TRAVEL INTELLIGENCE
    </text>

    <!-- Live Status Pill Badge -->
    <g transform="translate(345, 524)">
      <rect x="0" y="0" width="110" height="26" rx="13" fill="#0F172A" />
      <circle cx="16" cy="13" r="5" fill="#10B981" />
      <text x="60" y="18" font-size="12" font-weight="800" fill="#38BDF8" letter-spacing="2" text-anchor="middle">LIVE OTA</text>
    </g>
  </g>
</svg>''';
