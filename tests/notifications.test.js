import {test} from 'node:test';
import assert from 'node:assert/strict';
import {notificationChanges} from '../dist/notifications.js';
test('only meaningful time/place changes produce text',()=>{const old={starts_at:'2099-01-01T10:00:00Z',city:'Warszawa',location:'Park'};assert.deepEqual(notificationChanges({kind:'event_changed',old_details:old,new_details:old}),[]);const text=notificationChanges({kind:'event_changed',old_details:old,new_details:{...old,city:'Kraków'}});assert.equal(text.length,1);assert.ok(text[0].includes('Warszawa, Park → Kraków, Park'));});
test('cancellation is distinct from changed time or place',()=>{assert.deepEqual(notificationChanges({kind:'event_cancelled'}),['Organizator odwołał spotkanie.']);});
