const puppeteer = require('puppeteer');
const fs = require('fs');

const fetchYears = (async () => {
  const browser = await puppeteer.launch();

  const fetchYear = async (year) => {
    const page = await browser.newPage();
    const result = {};
    try {
      page.on('response', async (res) => {
        const url = res.url();
        const isFinalist = url.includes('finalist');
        const isWinner = url.includes('winner');
        if (url.includes('json') && (isFinalist || isWinner)) {
          console.log(url);
          const text = await res.text();
          if (isFinalist) {
            result.finalists = text;
          } else if (isWinner) {
            result.winners = text;
          }
        }
      });
      await page.goto('https://www.pulitzer.org/prize-winners-by-year/' + year,
        {waitUntil: 'networkidle0'});
    } catch (e) {
      console.log('e', e);
    }
    return result;
  }

  for (let year = 1917; year <= 2018; year++) {
    console.log(year);
    const result = await fetchYear(year);
    fs.writeFileSync('data/' + year + '.json', JSON.stringify(result));
  }

  await browser.close();
});

const fetchWinners = (async (year) => {
  const browser = await puppeteer.launch();

  let {winners, finalists} = JSON.parse(fs.readFileSync('data/' + year + '.json'));
  winners = JSON.parse(winners);

  const results = [];

  await Promise.all(winners.map(async winner => {
    const nid = winner.nid;
    const url = 'https://www.pulitzer.org/node/' + nid;
    const page = await browser.newPage();
    console.log(winner);
    try {
      page.on('response', async (res) => {
        if (res.url().includes('node/' + nid) && res.url().includes('json')) {
          results.push(await res.text());
        }
      });
      await page.goto(url, {waitUntil: 'networkidle0'});
    } catch (e) {
      console.log('e', e);
    }
    await page.close();
  }));

  fs.writeFileSync('data/winners-' + year + '.json', JSON.stringify(results));

  await browser.close();
});

(async function() {
  for (let year = 2017; year >= 1917; year--) {
    await fetchWinners(year);
  }
})();