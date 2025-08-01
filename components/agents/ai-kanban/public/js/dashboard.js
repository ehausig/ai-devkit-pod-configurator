class KanbanDashboard {
    constructor() {
        this.ws = null;
        this.cards = new Map();
        this.agents = new Map(); // Track all agents that have participated
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
            try {
                const message = JSON.parse(event.data);
                this.handleWebSocketMessage(message);
            } catch (error) {
                console.error('Error parsing WebSocket message:', error);
                console.error('Raw message:', event.data);
            }
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
            
            if (data.status) {
                this.updateJournalStatus(data.status);
            }
            
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
        try {
            switch (message.type) {
                case 'initial':
                    if (message.data.status) {
                        this.updateJournalStatus(message.data.status);
                    }
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
                    
                case 'status':
                    this.updateJournalStatus(message.data);
                    break;
            }
        } catch (error) {
            console.error('Error handling WebSocket message:', error);
            console.error('Message data:', message);
        }
    }

    updateJournalStatus(status) {
        // Create or update status message
        let statusElement = document.getElementById('journal-status');
        if (!statusElement) {
            // Create status element if it doesn't exist
            const board = document.getElementById('kanban-board');
            statusElement = document.createElement('div');
            statusElement.id = 'journal-status';
            statusElement.className = 'journal-status';
            board.parentNode.insertBefore(statusElement, board);
        }
        
        // Update status content
        statusElement.className = `journal-status ${status.type}`;
        
        let html = `<div class="status-icon"></div><div class="status-content">`;
        html += `<div class="status-message">${status.message}</div>`;
        
        if (status.details) {
            html += `<div class="status-details">${status.details}</div>`;
        }
        
        html += `</div>`;
        statusElement.innerHTML = html;
        
        // Hide status if connected
        if (status.type === 'connected') {
            setTimeout(() => {
                statusElement.style.display = 'none';
            }, 3000);
        } else {
            statusElement.style.display = 'flex';
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
            let targetColumn = null;
            
            // Handle special states
            if (card.blocked) {
                // If card is blocked, keep it in its current column but with blocked styling
                targetColumn = document.querySelector(`[data-state="${card.state}"] .column-cards`);
            } else {
                targetColumn = document.querySelector(`[data-state="${card.state}"] .column-cards`);
            }
            
            if (targetColumn) {
                const cardElement = this.createCardElement(card);
                targetColumn.appendChild(cardElement);
                
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
        
        // Add state-specific class for styling
        if (card.state) {
            div.classList.add(`state-${card.state}`);
        }
        
        if (card.blocked) {
            div.classList.add('blocked');
        }
        
        // Create state band explicitly
        const stateBand = document.createElement('div');
        stateBand.className = 'card-state-band';
        div.appendChild(stateBand);
        
        // Add state icon
        const stateIcon = document.createElement('span');
        stateIcon.className = 'card-state-icon';
        
        // Set icon based on state
        if (card.blocked || card.state === 'blocked') {
            stateIcon.textContent = '⚠️';
        } else if (card.state && card.state.endsWith('_started')) {
            stateIcon.textContent = '⏳';
        } else if (card.state && card.state.endsWith('_ended')) {
            stateIcon.textContent = '✓';
        } else if (card.state === 'done') {
            stateIcon.textContent = '✨';
        }
        
        if (stateIcon.textContent) {
            div.appendChild(stateIcon);
        }
        
        // Create card content
        const content = document.createElement('div');
        content.className = 'card-content';
        content.innerHTML = `
            <div class="card-id">${card.id}</div>
            <div class="card-title">${this.escapeHtml(card.title)}</div>
            <div class="card-meta">
                <span class="card-assigned">${card.assigned_to ? '👤 ' + card.assigned_to : ''}</span>
                <span class="card-dependencies">${card.dependencies && card.dependencies.length > 0 ? '🔗 ' + card.dependencies.length : ''}</span>
            </div>
        `;
        
        div.appendChild(content);
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
                const actor = history.actor || 'system';
                item.innerHTML = `
                    <div class="history-time">${time}</div>
                    <div>
                        <span class="history-state">${history.state}</span>
                        <span class="history-actor">by ${actor}</span>
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
            
            // Add agent to our tracking map if not already present
            if (!this.agents.has(agent.agent)) {
                this.agents.set(agent.agent, {
                    name: agent.agent,
                    lastSeen: new Date(),
                    status: agent.status
                });
            }
            
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
        try {
            // Track agent activity from events
            if (event.event_type === 'agent.activated') {
                this.handleAgentActivation(event);
            } else if (event.event_type === 'agent.deactivated') {
                this.handleAgentDeactivation(event);
            }
            
            this.addEventToLog(event);
            
            // Keep only last 50 events
            const eventList = document.getElementById('event-list');
            while (eventList.children.length > 50) {
                eventList.removeChild(eventList.lastChild);
            }
        } catch (error) {
            console.error('Error adding event:', error);
            console.error('Event data:', event);
        }
    } events
        if (event.event_type === 'agent.activated') {
            this.handleAgentActivation(event);
        } else if (event.event_type === 'agent.deactivated') {
            this.handleAgentDeactivation(event);
        }
        
        this.addEventToLog(event);
        
        // Keep only last 50 events
        const eventList = document.getElementById('event-list');
        while (eventList.children.length > 50) {
            eventList.removeChild(eventList.lastChild);
        }
    }

    handleAgentActivation(event) {
        // Update agent status to active
        if (!this.agents.has(event.agent)) {
            this.agents.set(event.agent, {
                name: event.agent,
                lastSeen: new Date(event.timestamp),
                status: 'active'
            });
        } else {
            const agent = this.agents.get(event.agent);
            agent.status = 'active';
            agent.lastSeen = new Date(event.timestamp);
        }
        
        // Set all other agents to idle
        this.agents.forEach((agent, name) => {
            if (name !== event.agent) {
                agent.status = 'idle';
            }
        });
        
        // Update the agent display
        this.refreshAgentDisplay();
    }

    handleAgentDeactivation(event) {
        // Update agent status to idle
        if (this.agents.has(event.agent)) {
            const agent = this.agents.get(event.agent);
            agent.status = 'idle';
            agent.lastSeen = new Date(event.timestamp);
        }
        
        // Update the agent display
        this.refreshAgentDisplay();
    }

    refreshAgentDisplay() {
        const agentList = document.getElementById('agent-list');
        agentList.innerHTML = '';
        
        // Sort agents: active first, then by last seen
        const sortedAgents = Array.from(this.agents.values()).sort((a, b) => {
            if (a.status === 'active' && b.status !== 'active') return -1;
            if (a.status !== 'active' && b.status === 'active') return 1;
            return b.lastSeen - a.lastSeen;
        });
        
        sortedAgents.forEach(agent => {
            const div = document.createElement('div');
            div.className = 'agent-item';
            
            div.innerHTML = `
                <span class="agent-status-dot ${agent.status}"></span>
                <span class="agent-name">${agent.name}</span>
                <span class="agent-message"></span>
            `;
            
            agentList.appendChild(div);
        });
    }

    addEventToLog(event) {
        const eventList = document.getElementById('event-list');
        const div = document.createElement('div');
        div.className = 'event-item';
        
        const time = new Date(event.timestamp).toLocaleTimeString();
        const eventType = event.event_type.replace('kanban.', '').replace('agent.', '');
        const details = event.card_id || event.agent || '';
        
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
