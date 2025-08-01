class StateBuilder {
  constructor() {
    this.cards = new Map();
    this.events = [];
    this.activeAgents = new Map();
  }

  processEvent(event) {
    // Store all events
    this.events.push(event);

    // Process based on event type
    if (event.event_type === 'kanban.card.created') {
      this.handleCardCreated(event);
    } else if (event.event_type === 'kanban.card.state_changed') {
      this.handleStateChanged(event);
    } else if (event.event_type === 'kanban.card.blocked') {
      this.handleCardBlocked(event);
    } else if (event.event_type === 'kanban.card.unblocked') {
      this.handleCardUnblocked(event);
    } else if (event.event_type === 'kanban.card.assigned') {
      this.handleCardAssigned(event);
    } else if (event.event_type.startsWith('kanban.card.')) {
      // Handle old event types for backward compatibility
      this.handleLegacyKanbanEvent(event);
    } else if (event.event_type.startsWith('agent.')) {
      this.handleAgentEvent(event);
    }
  }

  handleCardCreated(event) {
    const card = {
      id: event.card_id,
      title: event.data.title || '',
      description: event.data.description || '',
      state: event.data.state || 'backlog',
      dependencies: event.data.dependencies || [],
      assigned_to: event.data.assigned_to || null,
      notes: event.data.notes || '',
      created_at: event.timestamp,
      blocked: false,
      blocked_reason: null,
      state_history: [{
        state: event.data.state || 'backlog',
        timestamp: event.timestamp,
        actor: event.actor
      }]
    };
    this.cards.set(event.card_id, card);
  }

  handleStateChanged(event) {
    const card = this.cards.get(event.card_id);
    if (!card) return;

    card.state = event.data.state;
    
    if (event.data.assigned_to !== undefined) {
      card.assigned_to = event.data.assigned_to === 'null' ? null : event.data.assigned_to;
    }
    
    if (event.data.notes) {
      card.notes = event.data.notes;
    }
    
    if (event.data.blocked !== undefined) {
      card.blocked = event.data.blocked;
    }
    
    if (event.data.blocked_reason !== undefined) {
      card.blocked_reason = event.data.blocked_reason;
    }

    // Add to state history
    card.state_history.push({
      state: event.data.state,
      timestamp: event.timestamp,
      actor: event.actor,
      previous_state: event.data.previous_state
    });
  }

  handleCardBlocked(event) {
    const card = this.cards.get(event.card_id);
    if (!card) return;

    card.blocked = true;
    card.blocked_reason = event.data.reason;
    card.previous_state = card.state;
    card.state = 'blocked';
  }

  handleCardUnblocked(event) {
    const card = this.cards.get(event.card_id);
    if (!card) return;

    card.blocked = false;
    card.blocked_reason = null;
    if (card.previous_state) {
      card.state = card.previous_state;
    }
  }

  handleCardAssigned(event) {
    const card = this.cards.get(event.card_id);
    if (!card) return;

    card.assigned_to = event.data.to;
  }

  handleLegacyKanbanEvent(event) {
    const card = this.cards.get(event.card_id);
    if (!card) return;

    // Map old event types to states
    const stateMap = {
      'kanban.card.breakdown.started': 'breakdown_started',
      'kanban.card.breakdown.ended': 'breakdown_ended',
      'kanban.card.work.started': 'work_started',
      'kanban.card.work.ended': 'work_ended',
      'kanban.card.validation.started': 'validation_started',
      'kanban.card.validation.ended': 'validation_ended',
      'kanban.card.completed': 'done'
    };

    const newState = stateMap[event.event_type];
    if (newState) {
      card.state = newState;
      card.state_history.push({
        state: newState,
        timestamp: event.timestamp,
        actor: event.actor
      });
    }
  }

  handleAgentEvent(event) {
    const agentId = event.actor;
    
    if (event.event_type === 'agent.started') {
      this.activeAgents.set(agentId, {
        agent: agentId,
        card_id: event.data.card_id,
        started_at: event.timestamp,
        status: 'active'
      });
    } else if (event.event_type === 'agent.completed') {
      const agent = this.activeAgents.get(agentId);
      if (agent) {
        agent.status = 'idle';
        agent.completed_at = event.timestamp;
      }
    }
  }

  getCurrentState() {
    return Array.from(this.cards.values()).map(card => ({
      ...card,
      dependencies_met: this.checkDependencies(card)
    }));
  }

  checkDependencies(card) {
    if (!card.dependencies || card.dependencies.length === 0) {
      return true;
    }

    return card.dependencies.every(depId => {
      const depCard = this.cards.get(depId);
      return depCard && depCard.state === 'done';
    });
  }

  getEvents() {
    return this.events;
  }

  getActiveAgents() {
    const agents = Array.from(this.activeAgents.values());
    const now = new Date();
    
    // Mark agents as idle if they haven't reported in 5 minutes
    agents.forEach(agent => {
      const lastActive = new Date(agent.completed_at || agent.started_at);
      const minutesSinceActive = (now - lastActive) / 1000 / 60;
      
      if (minutesSinceActive > 5 && agent.status === 'active') {
        agent.status = 'idle';
      }
    });

    return agents;
  }
}

module.exports = StateBuilder;
