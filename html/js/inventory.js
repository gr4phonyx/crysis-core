// =====================================================
// INVENTAIRE - JAVASCRIPT (CORRIGÉ)
// =====================================================

const InventoryManager = {
    container: null,
    grid: null,
    maxSlots: 30,
    maxWeight: 50.0,
    inventory: [],
    selectedItem: null,
    selectedSlot: null,

    init: function() {
        this.container = document.getElementById('inventoryContainer');
        this.grid = document.getElementById('inventoryGrid');
        
        // Générer les slots
        this.generateSlots();
        
        // Event listeners
        document.getElementById('closeInventory').addEventListener('click', () => this.close());
        document.getElementById('useItemBtn').addEventListener('click', () => this.useItem());
        document.getElementById('dropItemBtn').addEventListener('click', () => this.showDropModal());
        
        // Modal drop
        document.getElementById('cancelDrop').addEventListener('click', () => this.hideDropModal());
        document.getElementById('confirmDrop').addEventListener('click', () => this.dropItem());
        document.getElementById('decreaseQuantity').addEventListener('click', () => this.changeDropQuantity(-1));
        document.getElementById('increaseQuantity').addEventListener('click', () => this.changeDropQuantity(1));
        
        // ESC pour fermer
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && !this.container.classList.contains('hidden')) {
                this.close();
            }
        });
    },

    generateSlots: function() {
        this.grid.innerHTML = '';
        
        for (let i = 1; i <= this.maxSlots; i++) {
            const slot = document.createElement('div');
            slot.className = 'inventory-slot empty';
            slot.dataset.slot = i;
            
            const slotNumber = document.createElement('span');
            slotNumber.className = 'slot-number';
            slotNumber.textContent = i;
            slot.appendChild(slotNumber);
            
            slot.addEventListener('click', () => this.selectSlot(i));
            
            this.grid.appendChild(slot);
        }
    },

    open: function() {
        this.container.classList.remove('hidden');
        this.updateDisplay();
    },

    close: function() {
        this.container.classList.add('hidden');
        this.selectedItem = null;
        this.selectedSlot = null;
        this.hideItemDetails();
        
        fetch(`https://${GetParentResourceName()}/closeInventory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    },

    updateInventory: function(inventory, currentWeight, maxWeight) {
        this.inventory = inventory || [];
        this.maxWeight = maxWeight || 50.0;
        
        // Mettre à jour les statistiques
        document.getElementById('currentWeight').textContent = currentWeight.toFixed(2);
        document.getElementById('maxWeight').textContent = maxWeight.toFixed(2);
        document.getElementById('usedSlots').textContent = this.inventory.length;
        document.getElementById('maxSlots').textContent = this.maxSlots;
        
        // Rafraîchir l'affichage
        this.updateDisplay();
    },

    updateDisplay: function() {
        // Réinitialiser tous les slots
        const slots = this.grid.querySelectorAll('.inventory-slot');
        slots.forEach(slot => {
            slot.classList.add('empty');
            slot.classList.remove('selected');
            const slotNum = slot.querySelector('.slot-number');
            slot.innerHTML = '';
            slot.appendChild(slotNum);
        });
        
        // Remplir avec les items
        this.inventory.forEach(item => {
            const slot = this.grid.querySelector(`[data-slot="${item.slot}"]`);
            if (slot) {
                slot.classList.remove('empty');
                
                // Image - ✅ CORRECTION: Chemin relatif correct
                const img = document.createElement('img');
                img.className = 'item-image';
                img.src = `html/img/items/${item.image}`;
                img.alt = item.label;
                img.onerror = function() {
                    this.src = 'html/img/items/default.png';
                };
                slot.appendChild(img);
                
                // Nom
                const name = document.createElement('div');
                name.className = 'item-name-slot';
                name.textContent = item.label;
                slot.appendChild(name);
                
                // Quantité
                if (item.quantity > 1) {
                    const quantity = document.createElement('span');
                    quantity.className = 'item-quantity-badge';
                    quantity.textContent = item.quantity;
                    slot.appendChild(quantity);
                }
            }
        });
    },

    selectSlot: function(slotNumber) {
        const item = this.inventory.find(i => i.slot === slotNumber);
        
        if (!item) {
            this.selectedItem = null;
            this.selectedSlot = null;
            this.hideItemDetails();
            return;
        }
        
        // Désélectionner l'ancien slot
        const slots = this.grid.querySelectorAll('.inventory-slot');
        slots.forEach(s => s.classList.remove('selected'));
        
        // Sélectionner le nouveau
        const slot = this.grid.querySelector(`[data-slot="${slotNumber}"]`);
        if (slot) {
            slot.classList.add('selected');
        }
        
        this.selectedItem = item;
        this.selectedSlot = slotNumber;
        this.showItemDetails(item);
    },

    showItemDetails: function(item) {
        document.querySelector('.no-selection').classList.add('hidden');
        
        const details = document.getElementById('itemDetails');
        details.classList.remove('hidden');
        
        // ✅ CORRECTION: Chemin relatif correct
        document.getElementById('itemImage').src = `html/img/items/${item.image}`;
        document.getElementById('itemImage').onerror = function() {
            this.src = 'html/img/items/default.png';
        };
        
        document.getElementById('itemName').textContent = item.label;
        document.getElementById('itemType').textContent = this.getTypeLabel(item.type);
        document.getElementById('itemWeight').textContent = (item.weight * item.quantity).toFixed(2);
        document.getElementById('itemDescription').textContent = item.description || 'Aucune description disponible.';
        document.getElementById('itemQuantity').textContent = item.quantity;
        
        // Afficher/masquer le bouton utiliser
        const useBtn = document.getElementById('useItemBtn');
        if (item.usable) {
            useBtn.style.display = 'flex';
        } else {
            useBtn.style.display = 'none';
        }
    },

    hideItemDetails: function() {
        document.querySelector('.no-selection').classList.remove('hidden');
        document.getElementById('itemDetails').classList.add('hidden');
    },

    getTypeLabel: function(type) {
        const types = {
            'item': 'Objet',
            'weapon': 'Arme',
            'food': 'Nourriture',
            'drink': 'Boisson',
            'tool': 'Outil',
            'other': 'Autre'
        };
        return types[type] || 'Objet';
    },

    useItem: function() {
        if (!this.selectedItem) return;
        
        fetch(`https://${GetParentResourceName()}/useItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                itemName: this.selectedItem.name
            })
        });
        
        // Fermer l'inventaire après utilisation
        this.close();
    },

    showDropModal: function() {
        if (!this.selectedItem) return;
        
        document.getElementById('dropModal').classList.remove('hidden');
        
        const input = document.getElementById('dropQuantity');
        input.value = 1;
        input.max = this.selectedItem.quantity;
    },

    hideDropModal: function() {
        document.getElementById('dropModal').classList.add('hidden');
    },

    changeDropQuantity: function(delta) {
        const input = document.getElementById('dropQuantity');
        let newValue = parseInt(input.value) + delta;
        newValue = Math.max(1, Math.min(newValue, this.selectedItem.quantity));
        input.value = newValue;
    },

    dropItem: function() {
        if (!this.selectedItem) return;
        
        const quantity = parseInt(document.getElementById('dropQuantity').value);
        
        fetch(`https://${GetParentResourceName()}/dropItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                itemName: this.selectedItem.name,
                quantity: quantity
            })
        });
        
        this.hideDropModal();
        this.close();
    }
};

// Initialisation
document.addEventListener('DOMContentLoaded', function() {
    InventoryManager.init();
});

// Messages de FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'openInventory':
            InventoryManager.open();
            InventoryManager.updateInventory(
                data.inventory,
                data.currentWeight,
                data.maxWeight
            );
            break;
            
        case 'closeInventory':
            InventoryManager.close();
            break;
            
        case 'updateInventory':
            InventoryManager.updateInventory(
                data.inventory,
                data.currentWeight,
                data.maxWeight || 50.0
            );
            break;
    }
});

function GetParentResourceName() {
    if (window.location.hostname === 'nui-game-internal') {
        return window.location.pathname.replace(/^\/|\/$/g, '').split('/')[0];
    }
    return "crysis-core";
}