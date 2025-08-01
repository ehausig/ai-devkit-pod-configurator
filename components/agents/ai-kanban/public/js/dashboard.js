class KanbanDashboard {
    constructor() {
        this.ws = null;
        this.cards = new Map();
        this.reconnectInterval = null;
        this.init();
    }

    init() {
        this.connectWebSocket();
        this.setupEventListeners();
        this.loadInitialData();
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}`;
        
        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.updateConnectionStatus(true);
            
            if (this.reconnectInterval) {
                clearInterval(this.reconnectInterval);
                this.reconnectInterval = null;
            }
        };

        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            this.handleWebSocketMessage(message);
        };

        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            this.updateConnectionStatus(false);
            this.scheduleReconnect();
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }

    scheduleReconnect() {
        if (!this.reconnectInterval) {
            this.reconnectInterval = setInterval(() => {
                console.log('Attempting to reconnect...');
                this.connectWebSocket();
            }, 5000);
        }
    }

    updateConnectionStatus(connected) {
        const indicator = document.getElementById('connection-status');
        const text = document.getElementById('connection-text');
        
        if (connected) {
            indicator.classList.remove('disconnected');
            indicator.classList.add('connected');
            text.textContent = 'Connected';
        } else {
            indicator.classList.remove('connected');
            indicator.classList.add('disconnected');
            text.textContent = 'Disconnected';
        }
    }

    async loadInitialData() {
        try {
            const response = await fetch('/api/state');
            const data = await response.json();
            
            if (data.cards) {
                this.updateBoard(data.cards);
            }
            
            if (data.metrics) {
                this.updateMetrics(data.metrics);
            }
        } catch (error) {
            console.error('Error loading initial data:', error);
        }
    }

    handleWebSocketMessage(message) {
        switch (message.type) {
            case 'initial':
                this.updateBoard(message.data.cards);
                this.updateMetrics(message.data.metrics);
                this.updateAgents(message.data.agents);
                this.updateEventLog(message.data.recentEvents);
                break;
                
            case 'event':
                this.addEvent(message.data.event);
                this.updateBoard(message.data.cards);
                this.updateMetrics(message.data.metrics);
                this.updateAgents(message.data.agents);
                break;
        }
    }

    updateBoard(cards) {
        // Clear all columns
        const columns = document.querySelectorAll('.column-cards');
        columns.forEach(col => col.innerHTML = '');
        
        // Reset column counts
        const counts = {};
        
        // Add cards to appropriate columns
        cards.forEach(card => {
            this.cards.set(card.id, card);
            const column = document.querySelector(`[data-state="${card.state}"] .column-cards`);
            
            if (column) {
                const cardElement = this.createCardElement(card);
                column.appendChild(cardElement);
                
                // Update count
                counts[card.state] = (counts[card.state] || 0) + 1;
            }
        });
        
        // Update column counts
        document.querySelectorAll('.kanban-column').forEach(col => {
            const state = col.dataset.state;
            const count = counts[state] || 0;
            col.querySelector('.card-count').textContent = count;
        });
    }

    createCardElement(card) {
        const div = document.createElement('div');
        div.className = 'kanban-card';
        if (card.blocked) {
            div.classList.add('blocked');
        }
        
        div.innerHTML = `
            <div class="card-id">${card.id}</div>
            <div class="card-title">${this.escapeHtml(card.title)}</div>
            <div class="card-meta">
                <span class="card-assigned">${card.assigned_to ? '👤 ' + card.assigned_to : ''}</span>
                <span class="card-dependencies">${card.dependencies.length > 0 ? '🔗 ' + card.dependencies.length : ''}</span>
            </div>
        `;
        
        div.addEventListener('click', () => this.showCardDetails(card));
        
        return div;
    }

    showCardDetails(card) {
        const modal = document.getElementById('card-modal');
        
        document.getElementById('modal-card-id').textContent = card.id;
        document.getElementById('modal-card-title').textContent = card.title;
        document.getElementById('modal-card-description').textContent = card.description || 'No description';
        document.getElementById('modal-card-state').textContent = card.state;
        document.getElementById('modal-card-assigned').textContent = card.assigned_to || 'Unassigned';
        document.getElementById('modal-card-dependencies').textContent = 
            card.dependencies.length > 0 ? card.dependencies.join(', ') : 'None';
        document.getElementById('modal-card-notes').textContent = card.notes || 'No notes';
        
        // Show state history
        const historyDiv = document.getElementById('modal-state-history');
        historyDiv.innerHTML = '';
        
        if (card.state_history && card.state_history.length > 0) {
            card.state_history.reverse().forEach(history => {
                const item = document.createElement('div');
                item.className = 'history-item';
                
                const time = new Date(history.timestamp).toLocaleTimeString();
                item.innerHTML = `
                    <div class="history-time">${time}</div>
                    <div>
                        <span class="history-state">${history.state}</span>
                        <span class="history-actor">by ${history.actor}</span>
                    </div>
                `;
                
                historyDiv.appendChild(item);
            });
        }
        
        modal.style.display = 'block';
    }

    updateMetrics(metrics) {
        document.getElementById('metric-total').textContent = metrics.totalCards || 0;
        document.getElementById('metric-completed').textContent = metrics.completedCards || 0;
        document.getElementById('metric-blocked').textContent = metrics.blockedCards || 0;
        document.getElementById('metric-progress').textContent = `${metrics.completionRate || 0}%`;
        document.getElementById('metric-agents').textContent = metrics.activeAgents || 0;
    }

    updateAgents(agents) {
        const agentList = document.getElementById('agent-list');
        agentList.innerHTML = '';
        
        if (!agents || agents.length === 0) {
            agentList.innerHTML = '<div class="agent-item">No active agents</div>';
            return;
        }
        
        agents.forEach(agent => {
            const div = document.createElement('div');
            div.className = 'agent-item';
            
            div.innerHTML = `
                <span class="agent-status-dot ${agent.status}"></span>
                <span class="agent-name">${agent.agent}</span>
                <span class="agent-card">${agent.card_id || 'Idle'}</span>
            `;
            
            agentList.appendChild(div);
        });
    }

    updateEventLog(events) {
        const eventList = document.getElementById('event-list');
        eventList.innerHTML = '';
        
        if (!events || events.length === 0) {
            return;
        }
        
        events.reverse().forEach(event => {
            this.addEventToLog(event);
        });
    }

    addEvent(event) {
        this.addEventToLog(event);
        
        // Keep only last 50 events
        const eventList = document.getElementById('event-list');
        while (eventList.children.length > 50) {
            eventList.removeChild(eventList.lastChild);
        }
    }

    addEventToLog(event) {
        const eventList = document.getElementById('event-list');
        const div = document.createElement('div');
        div.className = 'event-item';
        
        const time = new Date(event.timestamp).toLocaleTimeString();
        const eventType = event.event_type.replace('kanban.', '').replace('agent.', '');
        const details = event.card_id || event.actor || '';
        
        div.innerHTML = `
            <span class="event-time">${time}</span>
            <span class="event-type">${eventType}</span>
            <span class="event-details">${details}</span>
        `;
        
        eventList.insertBefore(div, eventList.firstChild);
    }

    setupEventListeners() {
        // Modal close button
        const modal = document.getElementById('card-modal');
        const closeBtn = modal.querySelector('.close');
        
        closeBtn.onclick = () => {
            modal.style.display = 'none';
        };
        
        window.onclick = (event) => {
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        };
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize dashboard when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new KanbanDashboard();
});
