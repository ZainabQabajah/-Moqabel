import { test } from 'node:test';
import assert from 'node:assert/strict';
import { matchItems } from '../lib/matching.ts';
import type { Item } from '../lib/types.ts';
const base:Item={id:'1',owner_id:'a',title:'Headphones',description:'test item',category:'electronics',wanted_categories:['books'],wanted_text:'books',city:'رام الله',condition:'جيد',image_url:'https://example.com/a.jpg',status:'available',created_at:'2026-01-01'};
test('matches require reciprocal category preferences',()=>{const target={...base,id:'2',owner_id:'b',category:'books' as const,wanted_categories:['electronics' as const]};assert.equal(matchItems([base],[target]).length,1);assert.equal(matchItems([base],[{...target,wanted_categories:['gaming']}]).length,0);});
test('own or reserved goods never become matches',()=>{assert.equal(matchItems([base],[{...base,category:'books'}]).length,0);assert.equal(matchItems([base],[{...base,owner_id:'b',category:'books',wanted_categories:['electronics'],status:'reserved'}]).length,0);});
test('same-city candidates rank before distant matches',()=>{const target={...base,owner_id:'b',category:'books' as const,wanted_categories:['electronics' as const]};const found=matchItems([base],[{...target,id:'far',city:'نابلس'},{...target,id:'near'}]);assert.deepEqual(found.map(x=>x.item.id),['near','far']);assert.equal(found[0].sameCity,true);});
