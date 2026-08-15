/// Shared conversation topics. Agents subscribe by topic, not by hardcoded calls.
abstract final class AgentTopics {
  static const sessionStart = 'session.start';
  static const sessionComplete = 'session.complete';
  static const sessionFailed = 'session.failed';

  static const planReady = 'plan.ready';
  static const designReady = 'design.ready';
  static const codeReady = 'code.ready';
  static const reviewChanges = 'review.changes';
  static const reviewApproved = 'review.approved';

  static const memoryRecall = 'memory.recall';
  static const memoryStore = 'memory.store';
  static const inferenceAsk = 'inference.ask';
  static const contractAsk = 'contract.ask';
  static const automationRecord = 'automation.record';
  static const voiceAnnounce = 'voice.announce';
  static const emergencyAlert = 'emergency.alert';
  static const statusUpdate = 'status.update';
}
