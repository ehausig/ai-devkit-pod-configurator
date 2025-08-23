class MetricsCalculator {
  getMetrics(cards, events) {
    const metrics = {
      totalCards: cards.length,
      cardsByState: this.getCardsByState(cards),
      blockedCards: cards.filter(c => c.blocked).length,
      completedCards: cards.filter(c => c.state === 'done').length,
      averageTimeInState: this.calculateAverageTimeInState(cards),
      throughput: this.calculateThroughput(events),
      activeAgents: this.getActiveAgentCount(events),
      completionRate: this.calculateCompletionRate(cards)
    };

    return metrics;
  }

  getCardsByState(cards) {
    const states = [
      'backlog',
      'breakdown_started',
      'breakdown_ended',
      'work_started',
      'work_ended',
      'validation_started',
      'validation_ended',
      'done',
      'blocked'
    ];

    const counts = {};
    states.forEach(state => {
      counts[state] = cards.filter(c => c.state === state).length;
    });

    return counts;
  }

  calculateAverageTimeInState(cards) {
    const timeByState = {};
    const countByState = {};

    cards.forEach(card => {
      if (!card.state_history || card.state_history.length < 2) return;

      for (let i = 0; i < card.state_history.length - 1; i++) {
        const current = card.state_history[i];
        const next = card.state_history[i + 1];
        
        const duration = new Date(next.timestamp) - new Date(current.timestamp);
        const hours = duration / 1000 / 60 / 60;

        if (!timeByState[current.state]) {
          timeByState[current.state] = 0;
          countByState[current.state] = 0;
        }

        timeByState[current.state] += hours;
        countByState[current.state]++;
      }
    });

    const averages = {};
    Object.keys(timeByState).forEach(state => {
      averages[state] = countByState[state] > 0 
        ? (timeByState[state] / countByState[state]).toFixed(1)
        : 0;
    });

    return averages;
  }

  calculateThroughput(events) {
    const now = new Date();
    const oneHourAgo = new Date(now - 60 * 60 * 1000);
    const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000);

    const completedEvents = events.filter(e => 
      e.event_type === 'kanban.card.completed' || 
      (e.event_type === 'kanban.card.state_changed' && e.data.state === 'done')
    );

    const lastHour = completedEvents.filter(e => 
      new Date(e.timestamp) > oneHourAgo
    ).length;

    const lastDay = completedEvents.filter(e => 
      new Date(e.timestamp) > oneDayAgo
    ).length;

    return {
      lastHour,
      lastDay,
      average: lastDay / 24
    };
  }

  getActiveAgentCount(events) {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const recentAgentEvents = events.filter(e => 
      e.event_type.startsWith('agent.') && 
      new Date(e.timestamp) > fiveMinutesAgo
    );

    const uniqueAgents = new Set(recentAgentEvents.map(e => e.actor));
    return uniqueAgents.size;
  }

  calculateCompletionRate(cards) {
    if (cards.length === 0) return 0;
    const completed = cards.filter(c => c.state === 'done').length;
    return Math.round((completed / cards.length) * 100);
  }
}

module.exports = MetricsCalculator;
