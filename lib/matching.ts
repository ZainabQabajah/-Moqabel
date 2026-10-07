import type { Item } from './types.ts';
// Scores indicate category/location compatibility, never verified value or trust.
export function matchItems(owned: Item[], available: Item[]) {
  return available.flatMap(target => {
    const candidates = owned.filter(mine => mine.owner_id !== target.owner_id && mine.status === 'available' && target.status === 'available' && mine.wanted_categories.includes(target.category) && target.wanted_categories.includes(mine.category));
    if (!candidates.length) return [];
    const mine = candidates.sort((a,b) => Number(b.city === target.city) - Number(a.city === target.city))[0];
    return [{ item: target, offered: mine, sameCity: mine.city === target.city, score: mine.city === target.city ? 100 : 75 }];
  }).sort((a,b) => b.score-a.score);
}
