export interface Category {
  id: string;
  userId: string;
  name: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
}

/** Category plus how many merchants reference it. */
export interface CategoryWithCount extends Category {
  merchantCount: number;
}

export interface CategoryUsage {
  merchants: number;
  cardRules: number;
}
