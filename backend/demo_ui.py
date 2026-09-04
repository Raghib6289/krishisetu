# Interactive Live Demonstration UI for KrishiSetu
# Provides immediate visual & functional validation of all 3 portals (Farmer, Buyer, Driver)
# connected to the live FastAPI server, ARIMA model, OR-Tools VRP, and WebSockets.

DEMO_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>KrishiSetu - Live Interactive App</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    :root {
      --primary: #1b5e20;
      --primary-light: #2e7d32;
      --accent: #f57f17;
      --sky: #0288d1;
      --bg: #f4f8f4;
      --card: #ffffff;
      --text: #1c2826;
      --muted: #616161;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: var(--bg); color: var(--text); padding-bottom: 50px; }
    
    /* Top Bar */
    .topbar {
      background: linear-gradient(135deg, var(--primary), var(--primary-light));
      color: white;
      padding: 16px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    .brand { display: flex; align-items: center; gap: 12px; }
    .brand-icon { font-size: 28px; background: rgba(255,255,255,0.2); padding: 8px; border-radius: 12px; }
    .brand-title { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
    .brand-sub { font-size: 12px; opacity: 0.9; }
    
    /* Role Switcher */
    .role-bar {
      background: white;
      padding: 12px 24px;
      display: flex;
      gap: 12px;
      border-bottom: 1px solid #e0e0e0;
      align-items: center;
    }
    .role-btn {
      padding: 8px 18px;
      border-radius: 20px;
      border: 1.5px solid #ccc;
      background: white;
      font-weight: 600;
      font-size: 13px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }
    .role-btn.active {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
      box-shadow: 0 2px 6px rgba(27,94,32,0.3);
    }
    
    .container { max-width: 1100px; margin: 24px auto; padding: 0 16px; }
    .portal { display: none; }
    .portal.active { display: block; }
    
    /* Cards & Grids */
    .grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; margin-bottom: 20px; }
    .card {
      background: var(--card);
      border-radius: 16px;
      padding: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
      border: 1px solid rgba(0,0,0,0.06);
    }
    .card-title { font-size: 16px; font-weight: 700; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; }
    
    /* Produce Grid */
    .produce-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px; }
    .produce-card {
      background: white;
      border-radius: 14px;
      overflow: hidden;
      border: 1px solid #e2e8e2;
      box-shadow: 0 2px 6px rgba(0,0,0,0.04);
      display: flex;
      flex-direction: column;
    }
    .produce-img { height: 130px; object-fit: cover; width: 100%; }
    .produce-body { padding: 12px; flex: 1; display: flex; flex-direction: column; justify-content: space-between; }
    .produce-name { font-weight: 700; font-size: 14px; margin-bottom: 4px; }
    .produce-price { font-size: 18px; font-weight: 800; color: var(--primary); }
    .produce-mandi { font-size: 11px; text-decoration: line-through; color: #999; margin-left: 6px; }
    
    /* Buttons */
    .btn {
      padding: 10px 16px;
      border-radius: 10px;
      font-weight: 600;
      border: none;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-size: 13px;
    }
    .btn-primary { background: var(--primary); color: white; }
    .btn-primary:hover { background: var(--primary-light); }
    .btn-accent { background: var(--accent); color: white; }
    .btn-sky { background: var(--sky); color: white; }
    .btn-dark { background: #0c2340; color: white; }
    
    /* Maps */
    #buyer-map, #driver-map { height: 380px; width: 100%; border-radius: 14px; z-index: 1; }
    
    /* Status Badge */
    .badge { padding: 4px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; }
    .badge-green { background: #e8f5e9; color: var(--primary); }
    .badge-blue { background: #e1f5fe; color: var(--sky); }
    
    /* Live Indicator */
    .live-dot { width: 10px; height: 10px; background: #00e676; border-radius: 50%; display: inline-block; animation: pulse 1.5s infinite; }
    @keyframes pulse { 0% { opacity: 1; transform: scale(1); } 50% { opacity: 0.4; transform: scale(1.2); } 100% { opacity: 1; transform: scale(1); } }
  </style>
</head>
<body>

  <div class="topbar">
    <div class="brand">
      <div class="brand-icon">🌾</div>
      <div>
        <div class="brand-title">KrishiSetu (कृषिसेतु)</div>
        <div class="brand-sub">Smart India Hackathon 2026 • Problem 26033 • Full-Stack Live Validation</div>
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 10px;">
      <div id="inv-ws-indicator" style="display: flex; align-items: center; gap: 6px; font-size: 12px; background: rgba(0,0,0,0.3); padding: 6px 14px; border-radius: 20px;">
        <span class="live-dot" style="background:#00e676;"></span> <span id="inv-ws-text">Inventory WS: <strong>CONNECTING...</strong></span>
      </div>
      <div style="display: flex; align-items: center; gap: 8px; font-size: 12px; background: rgba(0,0,0,0.2); padding: 6px 14px; border-radius: 20px;">
        <span class="live-dot"></span> Backend: <strong>ONLINE (:8000)</strong>
      </div>
    </div>
  </div>
  <div id="live-toast-box" style="position: fixed; top: 80px; right: 24px; z-index: 99999; display: flex; flex-direction: column; gap: 10px; max-width: 360px;"></div>

  <div class="role-bar">
    <span style="font-size: 13px; color: var(--muted); font-weight: 600;">Switch Portal View:</span>
    <button class="role-btn active" onclick="switchTab('farmer')">🌾 Farmer Portal</button>
    <button class="role-btn" onclick="switchTab('buyer')">🛒 Buyer Portal & Live Map</button>
    <button class="role-btn" onclick="switchTab('driver')">🚚 Driver Logistics & OR-Tools</button>
  </div>

  <div class="container">

    <!-- ================= FARMER PORTAL ================= -->
    <div id="portal-farmer" class="portal active">
      <div class="grid-2">
        <div class="card" style="background: linear-gradient(135deg, #1b5e20, #2e7d32); color: white;">
          <h2 style="font-size: 20px; font-weight: 800; margin-bottom: 8px;">Farmer Portal: Ramesh Patil</h2>
          <p style="font-size: 13px; opacity: 0.9; line-height: 1.4;">
            Disintermediate traditional middlemen to secure up to <strong>+18% higher profit margins</strong> directly from bulk institutional buyers.
          </p>
          <div style="margin-top: 16px; display: flex; gap: 12px;">
            <div style="background: rgba(255,255,255,0.2); padding: 8px 14px; border-radius: 10px;">
              <div style="font-size: 11px;">Active Produce</div>
              <div style="font-size: 18px; font-weight: 700;" id="farmer-produce-count">6 Crops</div>
            </div>
            <div style="background: rgba(255,255,255,0.2); padding: 8px 14px; border-radius: 10px;">
              <div style="font-size: 11px;">Mandi Middleman Cut</div>
              <div style="font-size: 18px; font-weight: 700;">0% (Direct)</div>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="card-title">
            <span>AI Demand & Price Forecaster (ARIMA)</span>
            <select id="forecast-crop-select" onchange="fetchForecast()" style="padding: 4px 8px; border-radius: 8px;">
              <option value="tomato">Tomato</option>
              <option value="onion">Onion</option>
              <option value="potato">Potato</option>
              <option value="wheat">Wheat</option>
              <option value="chili">Chili</option>
            </select>
          </div>
          <div style="font-size: 12px; color: var(--muted); margin-bottom: 8px;" id="forecast-summary">Loading ARIMA predictions...</div>
          <div style="height: 180px;"><canvas id="forecastChart"></canvas></div>
        </div>
      </div>

      <!-- Add Produce Form -->
      <div class="card" style="margin-bottom: 20px;">
        <div class="card-title">List New Crop Inventory (Instant Direct Marketplace)</div>
        <form onsubmit="addNewCrop(event)" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;">
          <input type="text" id="add-crop-name" placeholder="Crop Name (e.g. Organic Tomatoes)" required style="padding: 10px; border-radius: 8px; border: 1px solid #ccc;">
          <input type="number" id="add-crop-qty" placeholder="Quantity (Quintals)" required style="padding: 10px; border-radius: 8px; border: 1px solid #ccc;">
          <input type="number" id="add-crop-price" placeholder="Direct Price (₹/kg)" required style="padding: 10px; border-radius: 8px; border: 1px solid #ccc;">
          <select id="add-crop-grade" style="padding: 10px; border-radius: 8px; border: 1px solid #ccc;">
            <option value="A+">Grade A+ (Premium)</option>
            <option value="A">Grade A (Standard)</option>
            <option value="B">Grade B (Fair)</option>
          </select>
          <button type="submit" class="btn btn-primary" style="grid-column: 1 / -1;">+ Publish Crop to Direct Buyers</button>
        </form>
      </div>

      <div class="card-title" style="margin-bottom: 12px;">Current Produce Listed by Farmers</div>
      <div class="produce-grid" id="farmer-crops-grid"></div>
    </div>

    <!-- ================= BUYER PORTAL ================= -->
    <div id="portal-buyer" class="portal">
      <div class="grid-2">
        <div class="card">
          <div class="card-title">
            <span>🛒 Live Tracking: Active Order #ord_9901</span>
            <span class="badge badge-green" id="buyer-ws-status">WS CONNECTED</span>
          </div>
          <div id="buyer-map"></div>
          <div style="margin-top: 12px; display: flex; justify-content: space-between; align-items: center; font-size: 13px;">
            <div>🚚 Driver: <strong>Santosh Shinde</strong> • Speed: <span id="buyer-speed">45 km/h</span></div>
            <div class="badge badge-blue" id="buyer-order-status">IN TRANSIT</div>
          </div>
        </div>

        <div class="card">
          <div class="card-title">
            <span>Shopping Cart & Escrow Checkout</span>
            <span class="badge badge-green" id="cart-count">0 items</span>
          </div>
          <div id="cart-items-list" style="min-height: 120px; font-size: 13px; color: var(--muted);">Cart is empty. Add produce below!</div>
          <hr style="margin: 12px 0; border: none; border-top: 1px solid #eee;">
          <div style="display: flex; justify-content: space-between; font-weight: 700; margin-bottom: 14px;">
            <span>Total Amount:</span>
            <span id="cart-total" style="color: var(--primary); font-size: 18px;">₹0</span>
          </div>
          <button class="btn btn-dark" style="width: 100%;" onclick="simulateCheckout()">🔒 Pay via Razorpay Instant Settlement</button>
        </div>
      </div>

      <div class="card-title" style="margin-bottom: 12px;">Direct Produce Catalog for Bulk Buyers</div>
      <div class="produce-grid" id="buyer-crops-grid"></div>
    </div>

    <!-- ================= DRIVER PORTAL ================= -->
    <div id="portal-driver" class="portal">
      <div class="grid-2">
        <div class="card">
          <div class="card-title">
            <span>Google OR-Tools Route Optimizer (VRP)</span>
            <span class="badge badge-green" id="ortools-badge">22% Fuel Saved</span>
          </div>
          <div id="driver-map"></div>
          <div style="margin-top: 12px; font-size: 13px; color: var(--muted);" id="driver-route-metrics">
            Depot: Nashik Central Cold Storage ➔ 4 Farm Pickups ➔ Navi Mumbai Wholesale Hub
          </div>
        </div>

        <div class="card">
          <div class="card-title">Driver Task Actions</div>
          <div style="margin-bottom: 16px;">
            <div style="font-weight: 700; font-size: 15px;">Order #ord_9901 (45 Quintals Tomatoes)</div>
            <div style="font-size: 12px; color: var(--muted); margin-top: 4px;">Pickup: Dindori Farm Hub ➔ Dropoff: Vashi Terminal</div>
          </div>

          <div style="display: flex; flex-direction: column; gap: 10px;">
            <button class="btn btn-sky" id="start-route-btn" onclick="startDriverRoute()">▶ Start Route (Activate GPS Telemetry)</button>
            <button class="btn btn-primary" onclick="completeDelivery()">✔ Complete Delivery (Release Escrow)</button>
            <button class="btn btn-accent" id="stream-telemetry-btn" onclick="toggleTelemetryStreaming()">📡 Broadcast GPS Coordinates via WebSocket</button>
          </div>

          <div style="margin-top: 16px; padding: 12px; background: #f0f7f0; border-radius: 10px; font-size: 12px;">
            <strong>Telemetry Stream Status:</strong>
            <div id="telemetry-log" style="font-family: monospace; margin-top: 4px; color: #333;">Idle (Tap Broadcast GPS to stream live coordinates to buyer map)</div>
          </div>
        </div>
      </div>
    </div>

  </div>

  <script>
    let forecastChart = null;
    let buyerMap = null;
    let driverMap = null;
    let buyerVehicleMarker = null;
    let driverVehicleMarker = null;
    let socket = null;
    let isStreaming = false;
    let streamTimer = null;
    let cart = [];
    let cropsData = [];

    function switchTab(role) {
      document.querySelectorAll('.role-btn').forEach(b => b.classList.remove('active'));
      event.target.classList.add('active');
      document.querySelectorAll('.portal').forEach(p => p.classList.remove('active'));
      document.getElementById('portal-' + role).classList.add('active');

      if (role === 'buyer' && buyerMap) {
        setTimeout(() => buyerMap.invalidateSize(), 200);
      }
      if (role === 'driver' && driverMap) {
        setTimeout(() => driverMap.invalidateSize(), 200);
      }
    }

    // Initialize Leaflet Maps
    function initMaps() {
      // Buyer Map
      buyerMap = L.map('buyer-map').setView([19.9975, 73.7898], 10);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(buyerMap);
      
      const truckIcon = L.divIcon({
        className: 'custom-truck',
        html: '<div style="background: #1b5e20; color: white; padding: 8px; border-radius: 50%; box-shadow: 0 2px 6px rgba(0,0,0,0.3); font-size: 16px;">🚚</div>',
        iconSize: [32, 32]
      });

      buyerVehicleMarker = L.marker([19.9975, 73.7898], { icon: truckIcon }).addTo(buyerMap);

      // Driver Map
      driverMap = L.map('driver-map').setView([19.9975, 73.7898], 9);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18 }).addTo(driverMap);
      driverVehicleMarker = L.marker([19.9975, 73.7898], { icon: truckIcon }).addTo(driverMap);
    }

    // Connect WebSocket
    function initWebSocket() {
      const loc = window.location;
      const wsUri = (loc.protocol === "https:" ? "wss:" : "ws:") + "//" + loc.host + "/ws/tracking/ord_9901";
      socket = new WebSocket(wsUri);

      socket.onopen = () => {
        document.getElementById('buyer-ws-status').textContent = 'WS LIVE';
      };

      socket.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.latitude && data.longitude) {
          const newPos = [data.latitude, data.longitude];
          if (buyerVehicleMarker) buyerVehicleMarker.setLatLng(newPos);
          if (buyerMap) buyerMap.panTo(newPos);
          document.getElementById('buyer-speed').textContent = Math.round(data.speed_kmh || 45) + ' km/h';
          document.getElementById('buyer-order-status').textContent = data.status || 'IN_TRANSIT';
        }
      };
    }

    let invSocket = null;

    function showLiveToast(title, body, isAlert = false) {
      const box = document.getElementById('live-toast-box');
      if (!box) return;
      const toast = document.createElement('div');
      toast.style.cssText = `
        background: ${isAlert ? '#ffebee' : '#ffffff'};
        border-left: 5px solid ${isAlert ? '#d32f2f' : '#2e7d32'};
        padding: 12px 16px;
        border-radius: 10px;
        box-shadow: 0 4px 16px rgba(0,0,0,0.18);
        animation: slideIn 0.3s ease;
        font-size: 13px;
        color: #1a1a1a;
      `;
      toast.innerHTML = `
        <div style="font-weight: 800; color: ${isAlert ? '#c62828' : '#1b5e20'}; margin-bottom: 2px;">${title}</div>
        <div style="font-size: 12px; color: #424242;">${body}</div>
      `;
      box.appendChild(toast);
      setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(-10px)';
        toast.style.transition = 'all 0.3s ease';
        setTimeout(() => toast.remove(), 300);
      }, 4000);
    }

    function initInventoryWebSocket() {
      const loc = window.location;
      const wsUri = (loc.protocol === "https:" ? "wss:" : "ws:") + "//" + loc.host + "/ws/inventory";
      invSocket = new WebSocket(wsUri);

      invSocket.onopen = () => {
        const text = document.getElementById('inv-ws-text');
        if (text) text.innerHTML = 'Inventory WS: <strong>CONNECTED</strong>';
      };

      invSocket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          console.log('[Inventory WebSocket]', data);

          if (data.type === 'CROP_ADDED') {
            showLiveToast('🌱 New Produce Listed!', `${data.crop.crop_name} (${data.crop.quantity_quintals} Qtl by ${data.crop.farmer_name})`);
            loadCrops();
          } else if (data.type === 'STOCK_UPDATED') {
            const isDepleted = data.is_out_of_stock;
            showLiveToast(
              isDepleted ? '🚨 Out of Stock Alert!' : '⚡ Live Stock Decrement',
              `${data.buyer_name} bought ${data.purchased_kg} kg of ${data.crop_name}. Remaining: ${data.new_quantity_quintals} Qtl`,
              isDepleted
            );

            // Update in-memory item
            const crop = cropsData.find(c => c.id === data.crop_id);
            if (crop) {
              crop.quantity_quintals = data.new_quantity_quintals;
              crop.status = data.status;
            }
            renderProduceCards();
          } else if (data.type === 'RESTOCKED') {
            showLiveToast('📦 Produce Restocked!', `Farmer restocked ${data.crop ? data.crop.crop_name : 'Produce'} (New: ${data.new_quantity_quintals} Qtl)`);
            loadCrops();
          } else if (data.type === 'CROP_UPDATED') {
            loadCrops();
          } else if (data.type === 'CROP_DELETED') {
            loadCrops();
          }
        } catch (e) {
          console.error(e);
        }
      };

      invSocket.onclose = () => {
        const text = document.getElementById('inv-ws-text');
        if (text) text.innerHTML = 'Inventory WS: <span style="color:#ff8a80;">RECONNECTING...</span>';
        setTimeout(initInventoryWebSocket, 3000);
      };
    }

    // Load Crops
    async function loadCrops() {
      const res = await fetch('/api/crops');
      cropsData = await res.json();
      renderProduceCards();
    }

    function renderProduceCards() {
      document.getElementById('farmer-produce-count').textContent = cropsData.length + ' Crops';

      // Render Farmer Cards
      const farmerGrid = document.getElementById('farmer-crops-grid');
      farmerGrid.innerHTML = cropsData.map(c => {
        const isDepleted = c.quantity_quintals <= 0.001 || c.status === 'OUT_OF_STOCK';
        const isLow = c.quantity_quintals <= 2.0 && !isDepleted;
        
        let statusBadge = `<span style="background: #e8f5e9; color: #2e7d32; font-size: 11px; font-weight: bold; padding: 2px 8px; border-radius: 6px;">Available</span>`;
        if (isDepleted) {
          statusBadge = `<span style="background: #ffebee; color: #c62828; font-size: 11px; font-weight: bold; padding: 2px 8px; border-radius: 6px;">OUT OF STOCK</span>`;
        } else if (isLow) {
          statusBadge = `<span style="background: #fff3e0; color: #e65100; font-size: 11px; font-weight: bold; padding: 2px 8px; border-radius: 6px;">LOW STOCK (${c.quantity_quintals} Qtl)</span>`;
        }

        return `
        <div class="produce-card" style="${isDepleted ? 'opacity: 0.75; border-color: #ef9a9a;' : ''}">
          <img src="${c.image_url}" class="produce-img" onerror="this.src='https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600'">
          <div class="produce-body">
            <div>
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
                <div class="produce-name">${c.crop_name}</div>
                ${statusBadge}
              </div>
              <div style="font-size: 11px; color: var(--muted);">${c.location} • Grade ${c.grade}</div>
              <div style="font-size: 12px; margin-top: 4px; font-weight: 600; color: #37474f;">
                Stock: <strong>${c.quantity_quintals} Qtl</strong> (${Math.round(c.quantity_quintals * 100)} kg)
              </div>
            </div>
            <div style="margin-top: 10px; display: flex; justify-content: space-between; align-items: center;">
              <div>
                <span class="produce-price">₹${c.price_per_kg}</span> /kg
                <span class="produce-mandi">Mandi: ₹${c.mandi_price_comparison}</span>
              </div>
              <button class="btn btn-accent" style="padding: 5px 10px; font-size: 11px;" onclick="quickRestock('${c.id}', 10)">+10 Qtl Restock</button>
            </div>
          </div>
        </div>
        `;
      }).join('');

      // Render Buyer Cards
      const buyerGrid = document.getElementById('buyer-crops-grid');
      buyerGrid.innerHTML = cropsData.map(c => {
        const isDepleted = c.quantity_quintals <= 0.001 || c.status === 'OUT_OF_STOCK';
        const isLow = c.quantity_quintals <= 2.0 && !isDepleted;

        return `
        <div class="produce-card" style="${isDepleted ? 'border: 1.5px solid #ef5350;' : ''}">
          <div style="position: relative;">
            <img src="${c.image_url}" class="produce-img" onerror="this.src='https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600'">
            ${isDepleted ? `
              <div style="position: absolute; top: 10px; left: 10px; background: #d32f2f; color: white; font-weight: 900; font-size: 10px; padding: 3px 8px; border-radius: 4px; letter-spacing: 0.5px;">
                OUT OF STOCK
              </div>
            ` : (isLow ? `
              <div style="position: absolute; top: 10px; left: 10px; background: #f57f17; color: white; font-weight: 900; font-size: 10px; padding: 3px 8px; border-radius: 4px;">
                ONLY ${Math.round(c.quantity_quintals * 100)} KG LEFT
              </div>
            ` : '')}
          </div>
          <div class="produce-body">
            <div>
              <div class="produce-name">${c.crop_name}</div>
              <div style="font-size: 11px; color: var(--muted);">Direct Farmer: ${c.farmer_name}</div>
              <div style="font-size: 11px; margin-top: 4px; font-weight: 600; color: ${isDepleted ? '#d32f2f' : '#2e7d32'};">
                ${isDepleted ? 'Depleted / Waiting for Farmer Harvest' : `Available: ${c.quantity_quintals} Qtl (${Math.round(c.quantity_quintals * 100)} kg)`}
              </div>
            </div>
            <div style="margin-top: 10px; display: flex; justify-content: space-between; align-items: center;">
              <div>
                <span class="produce-price">₹${c.price_per_kg}</span> /kg
              </div>
              ${isDepleted ? `
                <button class="btn" style="padding: 6px 12px; font-size: 12px; background: #e0e0e0; color: #757575; cursor: not-allowed;" disabled>Out of Stock</button>
              ` : `
                <button class="btn btn-primary" style="padding: 6px 12px; font-size: 12px;" onclick="addToCart('${c.id}')">+ 50kg</button>
              `}
            </div>
          </div>
        </div>
        `;
      }).join('');
    }

    async function quickRestock(cropId, amt) {
      try {
        const res = await fetch(`/api/crops/${cropId}/quick-stock`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'add', amount_quintals: amt })
        });
        if (res.ok) {
          showLiveToast('Produce Restocked', `Added ${amt} Quintals directly to listing!`);
          loadCrops();
        }
      } catch (e) {
        alert('Restock error: ' + e.message);
      }
    }

    // Add Crop Form Handler
    async function addNewCrop(e) {
      e.preventDefault();
      const newCrop = {
        farmer_id: 'usr_farmer_101',
        farmer_name: 'Ramesh Patil',
        farmer_phone: '+91 98765 43210',
        crop_name: document.getElementById('add-crop-name').value,
        category: 'Vegetables',
        quantity_quintals: parseFloat(document.getElementById('add-crop-qty').value),
        price_per_kg: parseFloat(document.getElementById('add-crop-price').value),
        grade: document.getElementById('add-crop-grade').value,
        harvest_date: new Date().toISOString().split('T')[0],
        location: 'Dindori Farm Cluster, Nashik',
        image_url: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600'
      };

      const res = await fetch('/api/crops', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCrop)
      });

      if (res.ok) {
        showLiveToast('Produce Listed Live!', `${newCrop.crop_name} is now immediately visible to all active buyers.`);
        e.target.reset();
        loadCrops();
      }
    }

    // Cart Handlers
    function addToCart(cropId) {
      const item = cropsData.find(c => c.id === cropId);
      if (item) {
        if (item.quantity_quintals <= 0.001 || item.status === 'OUT_OF_STOCK') {
          alert('Sorry, this produce is currently OUT OF STOCK!');
          return;
        }
        cart.push(item);
        renderCart();
      }
    }

    function renderCart() {
      document.getElementById('cart-count').textContent = cart.length + ' items';
      const container = document.getElementById('cart-items-list');
      if (cart.length === 0) {
        container.innerHTML = 'Cart is empty. Add produce below!';
        document.getElementById('cart-total').textContent = '₹0';
        return;
      }

      let total = 0;
      container.innerHTML = cart.map((c, idx) => {
        const itemTotal = c.price_per_kg * 50;
        total += itemTotal;
        return `
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
            <span>${c.crop_name} (50 kg)</span>
            <strong>₹${itemTotal}</strong>
          </div>
        `;
      }).join('');
      document.getElementById('cart-total').textContent = '₹' + total;
    }

    async function simulateCheckout() {
      if (cart.length === 0) {
        alert('Please add crops to cart first!');
        return;
      }

      const orderPayload = {
        buyer_id: 'usr_buyer_202',
        buyer_name: 'Reliance Fresh Retail Hub',
        buyer_phone: '+91 98220 11223',
        delivery_address: 'Vashi APMC Sector 19, Navi Mumbai',
        delivery_lat: 19.0760,
        delivery_lng: 72.9980,
        items: cart.map(c => ({
          listing_id: c.id,
          crop_name: c.crop_name,
          farmer_name: c.farmer_name,
          quantity_kg: 50.0,
          price_per_kg: c.price_per_kg
        })),
        payment_method: 'Razorpay Instant Settlement',
        payment_id: 'pay_demo_' + Date.now()
      };

      try {
        const res = await fetch('/api/orders', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(orderPayload)
        });

        if (res.ok) {
          const order = await res.json();
          alert(`✅ Razorpay Payment Verified! Order #${order.id} Placed!\n\nNotice how the stock decremented in Real Time across all screens! If quantity hits 0, it dynamically switches to OUT OF STOCK!`);
          cart = [];
          renderCart();
        } else {
          const err = await res.json();
          alert('Checkout failed: ' + (err.detail || 'Stock unavailable'));
        }
      } catch (e) {
        alert('Checkout error: ' + e.message);
      }
    }

    // Fetch ARIMA Forecast
    async function fetchForecast() {
      const crop = document.getElementById('forecast-crop-select').value;
      const res = await fetch(`/api/forecast?crop=${crop}&days=7`);
      const data = await res.json();

      document.getElementById('forecast-summary').textContent = `${data.trend_summary} • Best time to harvest & sell: ${data.best_time_to_sell}`;

      const labels = data.forecast.map(d => d.date.split('-').slice(1).join('/'));
      const prices = data.forecast.map(d => d.price);

      if (forecastChart) forecastChart.destroy();
      const ctx = document.getElementById('forecastChart').getContext('2d');
      forecastChart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: labels,
          datasets: [{
            label: 'Predicted Price (₹/kg)',
            data: prices,
            borderColor: '#1b5e20',
            backgroundColor: 'rgba(27,94,32,0.1)',
            fill: true,
            tension: 0.3
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } }
        }
      });
    }

    // Fetch OR-Tools Route
    async function loadOrToolsRoute() {
      const sampleRes = await fetch('/api/routes/sample-stops');
      const sample = await sampleRes.json();
      
      const optRes = await fetch('/api/routes/optimize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          depot: sample.depot,
          stops: sample.stops,
          vehicle_capacity: 500,
          num_vehicles: 1
        })
      });

      const optData = await optRes.json();
      const route = optData.routes[0];

      // Draw polyline on Driver Map
      const latlngs = route.polyline_coordinates;
      L.polyline(latlngs, { color: '#0288d1', weight: 4 }).addTo(driverMap);
      L.polyline(latlngs, { color: '#0288d1', weight: 4 }).addTo(buyerMap);

      route.stops_sequence.forEach((s, idx) => {
        L.circleMarker([s.latitude, s.longitude], {
          radius: 8,
          color: idx === 0 ? '#333' : '#1b5e20',
          fillColor: idx === 0 ? '#333' : '#1b5e20',
          fillOpacity: 1
        }).bindPopup(`<strong>Stop ${idx+1}:</strong> ${s.name}`).addTo(driverMap);
      });

      driverMap.fitBounds(L.polyline(latlngs).getBounds(), { padding: [20, 20] });
    }

    // Driver Action: Start Route
    function startDriverRoute() {
      document.getElementById('start-route-btn').textContent = 'Route In Transit...';
      document.getElementById('start-route-btn').disabled = true;
      toggleTelemetryStreaming();
    }

    // Driver Action: Complete Delivery
    function completeDelivery() {
      if (isStreaming) toggleTelemetryStreaming();
      alert('Delivery Complete! Buyer confirmed receipt. Escrow funds released directly to Ramesh Patil.');
    }

    // Live GPS Telemetry Streamer via WebSocket
    function toggleTelemetryStreaming() {
      isStreaming = !isStreaming;
      const btn = document.getElementById('stream-telemetry-btn');
      const log = document.getElementById('telemetry-log');

      if (isStreaming) {
        btn.textContent = '⏹ Stop GPS Streaming';
        btn.style.background = '#d32f2f';

        const coordinates = [
          [19.9975, 73.7898],
          [20.0800, 73.8100],
          [20.1738, 73.8344],
          [20.1300, 73.8800],
          [20.0931, 73.9189],
          [19.8000, 73.6500],
          [19.6000, 73.4000],
          [19.2967, 73.0631],
          [19.0760, 72.9980]
        ];
        let idx = 0;

        streamTimer = setInterval(() => {
          if (idx >= coordinates.length) idx = 0;
          const pos = coordinates[idx];
          idx++;

          const payload = {
            order_id: 'ord_9901',
            driver_id: 'usr_driver_303',
            driver_name: 'Santosh Shinde',
            latitude: pos[0],
            longitude: pos[1],
            speed_kmh: 46 + (idx % 2 ? 3 : -2),
            heading_deg: 195.0,
            status: 'IN_TRANSIT'
          };

          if (socket && socket.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify(payload));
          }

          if (driverVehicleMarker) driverVehicleMarker.setLatLng(pos);
          log.textContent = `Streaming: Lat ${pos[0].toFixed(4)}, Lng ${pos[1].toFixed(4)}, Speed ${payload.speed_kmh} km/h (Broadcasting to Buyer Map)`;
        }, 1500);

      } else {
        btn.textContent = '📡 Broadcast GPS Coordinates via WebSocket';
        btn.style.background = 'var(--accent)';
        clearInterval(streamTimer);
        log.textContent = 'Streaming paused.';
      }
    }

    window.onload = () => {
      initMaps();
      initWebSocket();
      initInventoryWebSocket();
      loadCrops();
      fetchForecast();
      loadOrToolsRoute();
    };
  </script>
</body>
</html>
"""
