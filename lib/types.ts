export type Category = 'electronics' | 'gaming' | 'books';
export type Item = { id: string; owner_id: string; title: string; description: string; category: Category; wanted_categories: Category[]; wanted_text: string; city: string; condition: string; image_url: string; status: 'available'|'reserved'|'swapped'; created_at: string; owner_name?: string };
export type Offer = { id: string; proposer_id: string; recipient_id: string; offered_item_id: string; requested_item_id: string; status: 'pending'|'accepted'|'declined'|'cancelled'|'completed'|'disputed'; proposer_confirmed: boolean; recipient_confirmed: boolean; meeting_note: string; created_at: string };
export type Message = { id: string; offer_id: string; sender_id: string; body: string; created_at: string };
export const categories = { electronics: 'إلكترونيات', gaming: 'ألعاب', books: 'كتب' };
export const cities = ['رام الله', 'الخليل', 'نابلس', 'بيت لحم', 'القدس', 'جنين', 'طولكرم', 'قلقيلية', 'أريحا'];
