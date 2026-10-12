import {test} from 'node:test';
import assert from 'node:assert/strict';
import {monthlyReport,reportMonths,isReportMonth,roundedAmount,monthlyCsv} from '../lib/finance/monthly';
import {monthlyPdf} from '../lib/monthly-pdf';

test('round up amount at requested step and preserve original audit value',()=>{
 assert.deepEqual(roundedAmount(20_001,100),{amount:20_100,amount_original:20_001,amount_rounded:20_100,rounding_step:100,rounding_difference:99});
 assert.equal(roundedAmount(20_000,500).amount,20_000);
 assert.equal(roundedAmount(20_001,1_000).amount,21_000);
 assert.equal(roundedAmount(20_001,0).rounding_difference,0);
 assert.throws(()=>roundedAmount(20_000,250));
 assert.throws(()=>roundedAmount(1e12,100));
});

test('per-user report range returns only 3 or 6 months ending current month',()=>{
 assert.deepEqual(reportMonths('2026-10',3),['2026-08','2026-09','2026-10']);
 assert.deepEqual(reportMonths('2026-10',6),['2026-05','2026-06','2026-07','2026-08','2026-09','2026-10']);
 assert.equal(isReportMonth('2026-05','2026-10',3),false);
 assert.throws(()=>reportMonths('2026-10',4));
});

test('monthly summary uses rounded amounts, category shares, comparison, receipts and Indonesian export dates',()=>{
 const rows=[
  {id:'1',date:'2026-09-02',type:'income' as const,category:'Project',description:'Project kecil',amount:20_000},
  {id:'2',date:'2026-10-02',type:'expense' as const,category:'Makan & minum',description:'Sarapan',amount:1_500,amount_original:1_201,rounding_difference:299,receipt_path:'private'},
  {id:'3',date:'2026-10-03',type:'expense' as const,category:'Transportasi',description:'Bus',amount:500},
 ];
 const r=monthlyReport(rows,['2026-09','2026-10']);
 assert.equal(r[1].income,0);assert.equal(r[1].expense,2_000);assert.equal(r[1].net,-2_000);
 assert.equal(r[1].categories[0].share,75);assert.equal(r[1].incomeChange,'Tidak ada pembanding');
 assert.equal(r[1].expenseChange,'Baru');assert.equal(r[1].roundingDifference,299);
 const csv=monthlyCsv(r);assert.match(csv,/ada struk/);assert.match(csv,/02\/10\/2026/);assert.match(csv,/1500/);
 assert.equal(monthlyReport([],['2026-10'])[0].expense,0);
});

test('PDF export generates a printable PDF document with summary and transactions',async()=>{
 const reports=monthlyReport([{id:'20',date:'2026-10-04',type:'expense',category:'Makan & minum',description:'Rp20.000 project',amount:20_000,receipt_path:'private'}],['2026-10']);
 const pdf=await monthlyPdf(reports);
 assert.equal(pdf.subarray(0,4).toString(),'%PDF');
 assert.ok(pdf.length>1000);
});
