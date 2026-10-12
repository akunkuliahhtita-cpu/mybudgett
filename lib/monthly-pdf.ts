import PDFDocument from 'pdfkit';
import path from 'node:path';
import {readFileSync} from 'node:fs';
import {rupiah} from './finance';
import {dateLabel,monthLabel,monthlyReport} from './finance/monthly';
export async function monthlyPdf(reports:ReturnType<typeof monthlyReport>){
 const doc=new PDFDocument({size:'A4',margin:40,bufferPages:true,info:{Title:'Laporan My Budget',Author:'My Budget'}});
 doc.registerFont('Inter',readFileSync(path.join(process.cwd(),'node_modules/@fontsource/inter/files/inter-latin-400-normal.woff'))).font('Inter');
 const chunks:Buffer[]=[];const result=new Promise<Buffer>((resolve,reject)=>{doc.on('data',b=>chunks.push(b));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject);});
 const pageBottom=780;
 function room(height:number){if(doc.y+height>pageBottom)doc.addPage();}
 function line(text:string,size=10){doc.fontSize(size);room(doc.heightOfString(text,{width:515})+8);doc.fillColor('#183153').text(text,40,doc.y,{width:515}).moveDown(.4);}
 for(const [index,r] of reports.entries()){
  if(index)doc.addPage();line('My Budget · Laporan keuangan',19);line(monthLabel(r.month),15);
  line(`Pemasukan (+) ${rupiah(r.income)}   |   Pengeluaran (−) ${rupiah(r.expense)}`);
  line(`Selisih bersih: ${rupiah(r.net)}   |   Selisih pembulatan: ${rupiah(r.roundingDifference)}`);
  line(`Dibanding bulan lalu: pemasukan ${r.incomeChange}; pengeluaran ${r.expenseChange}.`,9);
  line('Nominal laporan memakai pembulatan. Selisih bersih bukan saldo rekening; saldo awal dan alokasi target tidak termasuk.',9);
  line('Ringkasan kategori',13);
  for(const c of r.categories)line(`${c.type==='income'?'+ Pemasukan':'− Pengeluaran'} · ${c.category}: ${rupiah(c.amount)} (${c.share.toLocaleString('id-ID',{maximumFractionDigits:1})}%)`,9);
  if(!r.categories.length)line('Belum ada transaksi bulan ini.');
  line('Daftar transaksi lengkap',13);
  const widths=[72,240,115,88],xs=[40,112,352,467];
  function header(){room(28);const y=doc.y;doc.rect(40,y,515,24).fill('#eff6ff');['Tanggal','Jenis / kategori / deskripsi','Nominal laporan','Audit / struk'].forEach((s,i)=>doc.fillColor('#183153').fontSize(9).text(s,xs[i]+4,y+5,{width:widths[i]-8}));doc.y=y+30;}
  header();
  for(const t of r.transactions){const values=[dateLabel(t.date),`${t.type==='income'?'+ Pemasukan':'− Pengeluaran'} · ${t.category}\n${t.description}`,rupiah(t.amount),`Asli ${rupiah(t.amount_original??t.amount)}\nSelisih ${rupiah(t.rounding_difference||0)}${t.receipt_path?'\nada struk':''}`];doc.fontSize(8);const height=Math.max(...values.map((v,i)=>doc.heightOfString(v,{width:widths[i]-8})))+12;if(doc.y+height>pageBottom){doc.addPage();header();}const y=doc.y;values.forEach((v,i)=>doc.fillColor('#183153').fontSize(8).text(v,xs[i]+4,y+4,{width:widths[i]-8}));doc.moveTo(40,y+height).lineTo(555,y+height).strokeColor('#dce5f2').stroke();doc.y=y+height+2;}
 }
 const pages=doc.bufferedPageRange();for(let i=pages.start;i<pages.start+pages.count;i++){doc.switchToPage(i);doc.fontSize(8).fillColor('#475569').text(`My Budget · ${i+1}/${pages.count}`,40,805,{width:515,lineBreak:false,align:'right'});}
 doc.end();return result;
}
