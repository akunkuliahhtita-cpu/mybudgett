import {type Transaction} from './index';
import {shiftMonth,compareAmount} from './reports';
export const roundingSteps=[0,100,500,1000] as const;
export function roundedAmount(original:number,step:number){
 if(!Number.isSafeInteger(original)||original<=0||original>1e12||!roundingSteps.includes(step as typeof roundingSteps[number]))throw new Error('Nominal atau pembulatan tidak valid.');
 const amount=step===0?original:Math.ceil(original/step)*step;
 if(amount>1e12)throw new Error('Nominal terlalu besar.');
 return {amount,amount_original:original,amount_rounded:amount,rounding_step:step,rounding_difference:amount-original};
}
export function reportMonths(current:string,range:number){if(range!==3&&range!==6)throw new Error('Rentang hanya 3 atau 6 bulan.');return Array.from({length:range},(_,i)=>shiftMonth(current,i-range+1));}
export function isReportMonth(month:string,current:string,range:number){return reportMonths(current,range).includes(month);}
export const dateLabel=(date:string)=>new Date(`${date}T12:00:00+07:00`).toLocaleDateString('id-ID',{timeZone:'Asia/Jakarta',day:'2-digit',month:'2-digit',year:'numeric'});
export const monthLabel=(month:string)=>new Date(`${month}-01T12:00:00+07:00`).toLocaleDateString('id-ID',{timeZone:'Asia/Jakarta',month:'long',year:'numeric'});
export function monthlyReport(rows:Transaction[],months:string[]){
 return months.map((month,i)=>{
  const transactions=rows.filter(t=>t.date.slice(0,7)===month).sort((a,b)=>a.date.localeCompare(b.date)||a.id.localeCompare(b.id));
  const sums=(ts:Transaction[])=>({income:ts.filter(t=>t.type==='income').reduce((s,t)=>s+t.amount,0),expense:ts.filter(t=>t.type==='expense').reduce((s,t)=>s+t.amount,0)});
  const totals=sums(transactions),previous=i>0?sums(rows.filter(t=>t.date.startsWith(months[i-1]))):null;
  const groups=new Map<string,{category:string;type:Transaction['type'];amount:number}>();
  for(const t of transactions){const key=`${t.type}:${t.category}`,g=groups.get(key)||{category:t.category,type:t.type,amount:0};g.amount+=t.amount;groups.set(key,g);}
  return {month,...totals,net:totals.income-totals.expense,roundingDifference:transactions.reduce((s,t)=>s+(t.rounding_difference||0),0),transactions,categories:[...groups.values()].map(c=>({...c,share:c.amount/(c.type==='income'?totals.income:totals.expense)*100})).sort((a,b)=>b.amount-a.amount),incomeChange:previous?compareAmount(totals.income,previous.income).label:'Di luar rentang akses',expenseChange:previous?compareAmount(totals.expense,previous.expense).label:'Di luar rentang akses'};
 });
}
export function monthlyCsv(reports:ReturnType<typeof monthlyReport>){
 const cell=(v:string|number)=>`"${String(typeof v==='string'&&/^\s*[=+\-@\t\r\n]/.test(v)?`'${v}`:v).replaceAll('"','""')}"`;
 const rows:(string|number)[][]=[['Tanggal','Jenis','Kategori','Deskripsi','Nominal asli (Rp)','Nominal laporan (Rp)','Selisih pembulatan (Rp)','Struk']];
 for(const r of reports)for(const t of r.transactions)rows.push([dateLabel(t.date),t.type==='income'?'Pemasukan':'Pengeluaran',t.category,t.description,t.amount_original??t.amount,t.amount,t.rounding_difference||0,t.receipt_path?'ada struk':'']);
 return '\uFEFF'+rows.map(r=>r.map(cell).join(';')).join('\r\n');
}
