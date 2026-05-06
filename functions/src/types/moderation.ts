/**
 * Moderation log + user reports. Stored under
 *   /filters/{id}/moderation/{auto}
 *   /filters/{id}/reports/{auto}
 */
export interface ModerationDecisionDoc {
  moderatorUid: string;
  action: "approve" | "reject" | "takedown";
  reason: string;
  notes: string;
  createdAt: FirebaseFirestore.Timestamp;
}

export interface ReportDoc {
  reporterUid: string;
  reason: string; // category code from /docs/API_SPEC.md §5.6
  message: string;
  createdAt: FirebaseFirestore.Timestamp;
}
