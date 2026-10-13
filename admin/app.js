(function () {
  'use strict';

  let currentRevision = '';
  let catalogItems = [];
  let activeCategory = 'all';
  let searchQuery = '';
  let globalEnabled = true;

  const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'dp_gameplay';

  // Elements
  const catalogTableBody = document.getElementById('catalogTableBody');
  const searchInput = document.getElementById('searchInput');
  const globalToggle = document.getElementById('globalToggle');
  const btnRefresh = document.getElementById('btnRefresh');
  const btnNewItem = document.getElementById('btnNewItem');
  const itemModal = document.getElementById('itemModal');
  const btnCloseModal = document.getElementById('btnCloseModal');
  const btnCancelModal = document.getElementById('btnCancelModal');
  const slingForm = document.getElementById('slingForm');
  const btnCalibrateInGame = document.getElementById('btnCalibrateInGame');
  const toastContainer = document.getElementById('toastContainer');

  // Stats Elements
  const statTotal = document.getElementById('statTotal');
  const statWeapons = document.getElementById('statWeapons');
  const statItems = document.getElementById('statItems');
  const statActive = document.getElementById('statActive');

  // Form Fields
  const fItemName = document.getElementById('fItemName');
  const fLabel = document.getElementById('fLabel');
  const fPropModel = document.getElementById('fPropModel');
  const fCategory = document.getElementById('fCategory');
  const fBone = document.getElementById('fBone');
  const fX = document.getElementById('fX');
  const fY = document.getElementById('fY');
  const fZ = document.getElementById('fZ');
  const fRotX = document.getElementById('fRotX');
  const fRotY = document.getElementById('fRotY');
  const fRotZ = document.getElementById('fRotZ');
  const fEnabled = document.getElementById('fEnabled');
  const modalTitle = document.getElementById('modalTitle');

  async function fetchNui(eventName, data = {}) {
    try {
      const res = await fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
      });
      return await res.json();
    } catch (err) {
      console.warn(`[slings-admin] Erro NUI em ${eventName}:`, err);
      return { ok: false, message: 'Falha de comunicação com o FiveM.' };
    }
  }

  function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `<i class="fa-solid fa-circle-info"></i> <span>${message}</span>`;
    toastContainer.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 3200);
  }

  async function loadCatalog() {
    const res = await fetchNui('getCatalog');
    if (!res || !res.ok) {
      showToast(res?.message || 'Erro ao carregar dados do catálogo.', 'error');
      return;
    }
    catalogItems = res.data?.records || [];
    currentRevision = res.data?.revision || '';
    globalEnabled = res.data?.enabled !== false;
    globalToggle.checked = globalEnabled;
    render();
  }

  function updateStats() {
    statTotal.textContent = catalogItems.length;
    let wepCount = 0;
    let itemCount = 0;
    let actCount = 0;

    catalogItems.forEach((i) => {
      if (i.category === 'rifle' || i.category === 'shotgun' || i.category === 'smg' || i.category === 'pistol' || i.category === 'sniper' || i.category === 'melee') {
        wepCount++;
      } else {
        itemCount++;
      }
      if (i.is_enabled) actCount++;
    });

    statWeapons.textContent = wepCount;
    statItems.textContent = itemCount;
    statActive.textContent = actCount;
  }

  function render() {
    updateStats();
    const query = searchQuery.toLowerCase().trim();
    const filtered = catalogItems.filter((item) => {
      const matchesCat = (activeCategory === 'all') || (item.category === activeCategory);
      const matchesQuery = !query ||
        item.item_name.toLowerCase().includes(query) ||
        item.label.toLowerCase().includes(query) ||
        item.prop_model.toLowerCase().includes(query);
      return matchesCat && matchesQuery;
    });

    if (filtered.length === 0) {
      catalogTableBody.innerHTML = `<tr><td colspan="8" style="text-align:center; padding: 32px; color: #8b9bb4;">Nenhum item encontrado com os filtros atuais.</td></tr>`;
      return;
    }

    catalogTableBody.innerHTML = filtered.map((item) => {
      const isEnabled = !!item.is_enabled;
      const bText = (item.bone === 24818) ? 'Peito (24818)' : ((item.bone === 24816) ? 'Costas (24816)' : (item.bone === 11816 ? 'Cintura (11816)' : item.bone));
      return `
        <tr>
          <td>
            <div class="item-badge">
              <span class="item-label">${escapeHtml(item.label)}</span>
              <span class="item-name">${escapeHtml(item.item_name)}</span>
            </div>
          </td>
          <td><code class="item-name">${escapeHtml(item.prop_model)}</code></td>
          <td><span class="badge-tag tag-${escapeHtml(item.category)}">${escapeHtml(item.category)}</span></td>
          <td><span class="bone-info">${bText}</span></td>
          <td><span class="coord-val">${Number(item.x).toFixed(2)}, ${Number(item.y).toFixed(2)}, ${Number(item.z).toFixed(2)}</span></td>
          <td><span class="coord-val">${Number(item.x_rot).toFixed(0)}°, ${Number(item.y_rot).toFixed(0)}°, ${Number(item.z_rot).toFixed(0)}°</span></td>
          <td>
            <label class="switch">
              <input type="checkbox" ${isEnabled ? 'checked' : ''} onchange="window.handleToggleItem('${escapeHtml(item.item_name)}', this.checked)">
              <span class="slider round"></span>
            </label>
          </td>
          <td>
            <div class="actions-cell">
              <button class="btn btn-warning btn-sm" onclick="window.handleCalibrate('${escapeHtml(item.item_name)}')"><i class="fa-solid fa-street-view"></i> 3D</button>
              <button class="btn btn-secondary btn-sm" onclick="window.handleEdit('${escapeHtml(item.item_name)}')"><i class="fa-solid fa-pen"></i></button>
              <button class="btn btn-danger btn-sm" onclick="window.handleDelete('${escapeHtml(item.item_name)}')"><i class="fa-solid fa-trash"></i></button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function openModal(item = null) {
    if (item) {
      modalTitle.innerHTML = `<i class="fa-solid fa-pen-to-square"></i> Editar Sling: ${escapeHtml(item.label)}`;
      fItemName.value = item.item_name;
      fItemName.disabled = true;
      fLabel.value = item.label;
      fPropModel.value = item.prop_model;
      fCategory.value = item.category || 'weapon';
      fBone.value = String(item.bone || 24818);
      fX.value = item.x || 0.0;
      fY.value = item.y || 0.0;
      fZ.value = item.z || 0.0;
      fRotX.value = item.x_rot || 0.0;
      fRotY.value = item.y_rot || 0.0;
      fRotZ.value = item.z_rot || 0.0;
      fEnabled.checked = item.is_enabled !== false;
    } else {
      modalTitle.innerHTML = `<i class="fa-solid fa-plus"></i> Novo Item para Sling`;
      fItemName.value = '';
      fItemName.disabled = false;
      fLabel.value = '';
      fPropModel.value = '';
      fCategory.value = 'rifle';
      fBone.value = '24818';
      fX.value = '-0.02';
      fY.value = '0.22';
      fZ.value = '-0.06';
      fRotX.value = '0.0';
      fRotY.value = '-30.0';
      fRotZ.value = '180.0';
      fEnabled.checked = true;
    }
    itemModal.classList.add('open');
  }

  function closeModal() {
    itemModal.classList.remove('open');
  }

  // Global methods for inline handlers
  window.handleToggleItem = async function (itemName, isChecked) {
    const res = await fetchNui('toggleItem', { itemName, enabled: isChecked });
    if (res && res.ok) {
      showToast(`Status de ${itemName} atualizado.`, 'success');
      catalogItems = res.data?.records || catalogItems;
      currentRevision = res.data?.revision || currentRevision;
      render();
    } else {
      showToast(res?.message || 'Falha ao alterar status.', 'error');
      loadCatalog();
    }
  };

  window.handleEdit = function (itemName) {
    const item = catalogItems.find((i) => i.item_name === itemName);
    if (item) openModal(item);
  };

  window.handleDelete = async function (itemName) {
    if (!confirm(`Tem certeza que deseja remover o sling do item ${itemName}?`)) return;
    const res = await fetchNui('deleteItem', { itemName });
    if (res && res.ok) {
      showToast(`Item ${itemName} removido com sucesso!`, 'success');
      catalogItems = res.data?.records || [];
      currentRevision = res.data?.revision || '';
      render();
    } else {
      showToast(res?.message || 'Falha ao remover item.', 'error');
    }
  };

  window.handleCalibrate = function (itemName) {
    const item = catalogItems.find((i) => i.item_name === itemName);
    if (!item) return;
    openModal(item);
    btnCalibrateInGame.click();
  };

  // Event Listeners
  btnRefresh.addEventListener('click', () => {
    loadCatalog();
    showToast('Catálogo recarregado.', 'info');
  });

  btnNewItem.addEventListener('click', () => openModal(null));
  btnCloseModal.addEventListener('click', closeModal);
  btnCancelModal.addEventListener('click', closeModal);

  searchInput.addEventListener('input', (e) => {
    searchQuery = e.target.value;
    render();
  });

  globalToggle.addEventListener('change', async (e) => {
    const res = await fetchNui('toggleGlobal', { enabled: e.target.checked });
    if (res && res.ok) {
      showToast(`Slings globais ${e.target.checked ? 'ativados' : 'desativados'} com sucesso!`, 'success');
    } else {
      showToast('Falha ao alterar switch global.', 'error');
      globalToggle.checked = !e.target.checked;
    }
  });

  document.getElementById('categoryFilters').addEventListener('click', (e) => {
    if (e.target.classList.contains('pill')) {
      document.querySelectorAll('.category-filters .pill').forEach((p) => p.classList.remove('active'));
      e.target.classList.add('active');
      activeCategory = e.target.getAttribute('data-cat');
      render();
    }
  });

  // Salvar Form
  slingForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const payload = {
      item_name: fItemName.value.trim(),
      label: fLabel.value.trim(),
      prop_model: fPropModel.value.trim(),
      category: fCategory.value,
      bone: parseInt(fBone.value, 10),
      x: parseFloat(fX.value) || 0.0,
      y: parseFloat(fY.value) || 0.0,
      z: parseFloat(fZ.value) || 0.0,
      x_rot: parseFloat(fRotX.value) || 0.0,
      y_rot: parseFloat(fRotY.value) || 0.0,
      z_rot: parseFloat(fRotZ.value) || 0.0,
      is_enabled: fEnabled.checked,
    };

    const res = await fetchNui('saveItem', { payload, revision: currentRevision });
    if (res && res.ok) {
      showToast('Item salvo e sincronizado para todos!', 'success');
      closeModal();
      catalogItems = res.data?.records || catalogItems;
      currentRevision = res.data?.revision || currentRevision;
      render();
    } else {
      showToast(res?.message || 'Falha ao salvar item.', 'error');
    }
  });

  // Calibrar In-Game (Captura 3D com câmera orbital)
  btnCalibrateInGame.addEventListener('click', async () => {
    const itemPayload = {
      item_name: fItemName.value.trim(),
      prop_model: fPropModel.value.trim() || fItemName.value.trim(),
      category: fCategory.value,
      bone: parseInt(fBone.value, 10),
      offset: {
        x: parseFloat(fX.value) || 0.0,
        y: parseFloat(fY.value) || 0.0,
        z: parseFloat(fZ.value) || 0.0,
        x_rot: parseFloat(fRotX.value) || 0.0,
        y_rot: parseFloat(fRotY.value) || 0.0,
        z_rot: parseFloat(fRotZ.value) || 0.0,
      }
    };

    showToast('Iniciando calibrador 3D in-game...', 'info');
    const res = await fetchNui('captureInGameCoords', { item: itemPayload });

    if (res && res.ok && res.offset) {
      fBone.value = String(res.bone || fBone.value);
      fX.value = Number(res.offset.x || 0).toFixed(3);
      fY.value = Number(res.offset.y || 0).toFixed(3);
      fZ.value = Number(res.offset.z || 0).toFixed(3);
      fRotX.value = Number(res.offset.x_rot || 0).toFixed(1);
      fRotY.value = Number(res.offset.y_rot || 0).toFixed(1);
      fRotZ.value = Number(res.offset.z_rot || 0).toFixed(1);
      showToast('Coordenadas capturadas com sucesso do ped!', 'success');
    } else {
      showToast(res?.message || 'Calibração cancelada.', 'info');
    }
  });

  // Inicialização SDK do Vanguard Plugin
  function initPlugin() {
    if (typeof VanguardPlugin !== 'undefined') {
      window.vanguardPlugin = new VanguardPlugin({
        id: 'slings',
        resource: resourceName,
        allowStandalone: true,
        isModalOpen: () => !!document.querySelector('.modal-overlay.open'),
        closeModal: () => closeModal(),
        onInit: () => loadCatalog(),
        onVisibility: (visible) => { if (visible) loadCatalog(); }
      });
    }
  }

  // ESC failsafe
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (itemModal.classList.contains('open')) {
        e.preventDefault();
        e.stopPropagation();
        closeModal();
        return;
      }
      if (window.vanguardPlugin && typeof window.vanguardPlugin.close === 'function') {
        window.vanguardPlugin.close();
      } else {
        fetchNui('closePanel');
      }
    }
  }, true);

  window.addEventListener('DOMContentLoaded', () => {
    initPlugin();
    loadCatalog();
  });
})();
