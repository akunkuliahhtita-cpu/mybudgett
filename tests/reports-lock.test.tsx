import { test } from 'node:test';
import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { LockedReports } from '../components/reports';
test('state terkunci hanya berisi manfaat dan CTA tanpa data laporan',()=>{
 const html=renderToStaticMarkup(<LockedReports upgrade={()=>{}}/>);
 assert.match(html,/Upgrade ke Premium/);
 assert.match(html,/Transaksimu tetap tersimpan/);
 assert.match(html,/Ringkasan bulanan, rincian kategori, transaksi lengkap, serta unduhan PDF dan CSV/);
 assert.match(html,/lucide-lock-keyhole/);
 assert.doesNotMatch(html,/<table|<svg[^>]*recharts|Rp[0-9]|report-summary|report-categories/);
});
