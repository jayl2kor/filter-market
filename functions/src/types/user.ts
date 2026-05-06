/**
 * Firestore /users/{uid} document shape. Counters are denormalized and
 * maintained by triggers in src/triggers/.
 */
export interface UserDoc {
  handle: string;
  displayName: string;
  bio: string;
  avatarUrl: string;
  locale: string;
  isMaker: boolean;
  isModerator: boolean;
  filterCount: number;
  followerCount: number;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}
