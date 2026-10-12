import type { NextConfig } from 'next';
const config: NextConfig = { devIndicators: false, serverExternalPackages:['pdfkit'], outputFileTracingIncludes:{'/api/monthly-reports':['./node_modules/@fontsource/inter/files/inter-latin-400-normal.woff']}, distDir: process.env.MYBUDGET_BUILD_DIR || '.next',
 ...(process.env.MYBUDGET_LOW_MEMORY==='1'?{experimental:{cpus:1,webpackBuildWorker:false,webpackMemoryOptimizations:true}}:{})
};
export default config;
