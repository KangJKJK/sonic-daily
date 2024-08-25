#!/bin/bash

# 색깔 변수 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Sonic 데일리퀘스트 미션 스크립트를 시작합니다...${NC}"

# 작업 디렉토리 설정
workDir2="/root/sonic-daily"

# 기존 작업 디렉토리가 존재하면 삭제
if [ -d "$workDir2" ]; then
    echo -e "${YELLOW}작업 디렉토리 '${workDir2}'가 이미 존재하므로 삭제합니다.${NC}"
    rm -rf "$workDir2"
fi

# 작업 디렉토리 새로 생성
echo -e "${YELLOW}새로운 작업 디렉토리 '${workDir2}'를 생성합니다.${NC}"
mkdir -p "$workDir2"
cd "$workDir2"

# 파일 다운로드 및 덮어쓰기
echo -e "${YELLOW}필요한 파일들을 다운로드합니다...${NC}"

# 존재하는 파일을 삭제하고 다운로드
rm -f package.json
curl -o package.json https://raw.githubusercontent.com/KangJKJK/sonic-checkin/main/package.json

rm -f package-lock.json
curl -o package-lock.json https://raw.githubusercontent.com/KangJKJK/sonic-checkin/main/package-lock.json

# npm 설치 여부 확인
echo -e "${YELLOW}필요한 파일들을 설치합니다...${NC}"
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm이 설치되지 않았습니다. npm을 설치합니다...${NC}"
    sudo apt-get update
    sudo apt-get install -y npm
else
    echo -e "${GREEN}npm이 이미 설치되어 있습니다.${NC}"
fi

# Node.js 모듈 설치
echo -e "${YELLOW}필요한 Node.js 모듈을 설치합니다...${NC}"
npm install
npm install @solana/web3.js chalk bs58

# 개인키 입력받기
read -p "Solana의 개인키를 쉼표로 구분하여 입력하세요: " privkeys

# 개인키를 파일에 저장
echo "$privkeys" > "$workDir2/sonicprivate.txt"

# 파일 생성 확인
if [ -f "$workDir2/sonicprivate.txt" ]; then
    echo -e "${GREEN}개인키 파일이 성공적으로 생성되었습니다.${NC}"
else
    echo -e "${RED}개인키 파일 생성에 실패했습니다.${NC}"
fi

# Node.js 스크립트 작성 (sonic-checkin.mjs)
echo -e "${YELLOW}Node.js 스크립트를 작성하고 있습니다...${NC}"
cat << 'EOF' > sonic-daily.mjs
import path from 'path';
import fs from 'fs';
import { Twisters } from 'twisters';
import { Connection, Keypair, PublicKey, SystemProgram, Transaction, LAMPORTS_PER_SOL } from '@solana/web3.js';
import bs58 from 'bs58';
import nacl from 'tweetnacl';
import fetch from 'node-fetch';

// 작업 디렉토리 설정
const workDir2 = '/root/sonic-daily';
if (!fs.existsSync(workDir2)) {
    fs.mkdirSync(workDir2, { recursive: true });
}
process.chdir(workDir2);

// 개인키 목록 읽기
const listAccounts = fs.readFileSync(path.join(workDir2, 'sonicprivate.txt'), 'utf-8')
    .split(",")
    .map(a => a.trim());

if (listAccounts.length === 0) {
    throw new Error('sonicprivate.txt에 개인키를 하나 이상 입력해주세요.');
}

const connection = new Connection('https://devnet.sonic.game/', 'confirmed');

function getKeypairFromPrivateKey(privateKey) {
    const decoded = bs58.decode(privateKey);
    return Keypair.fromSecretKey(decoded);
}

async function sendTransaction(transaction, keyPair) {
    try {
        transaction.partialSign(keyPair);
        const rawTransaction = transaction.serialize();
        const signature = await connection.sendRawTransaction(rawTransaction);
        await connection.confirmTransaction(signature);
        return signature;
    } catch (error) {
        return error;
    }
}

const delay = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));

const twocaptcha_turnstile = async (sitekey, pageurl) => {
    try {
        const getToken = await fetch(`https://2captcha.com/in.php?key=${captchaKey}&method=turnstile&sitekey=${sitekey}&pageurl=${pageurl}&json=1`)
            .then(res => res.text())
            .then(res => {
                if (res == 'ERROR_WRONG_USER_KEY' || res == 'ERROR_ZERO_BALANCE') {
                    return res;
                } else {
                    return res.split('|');
                }
            });

        if (getToken[0] != 'OK') {
            return 'FAILED_GETTING_TOKEN';
        }
    
        const task = getToken[1];

        for (let i = 0; i < 60; i++) {
            const token = await fetch(`https://2captcha.com/res.php?key=${captchaKey}&action=get&id=${task}&json=1`)
                .then(res => res.json());
            
            if (token.status == 1) {
                return token;
            }
            await delay(2);
        }
    } catch (error) {
        return 'FAILED_GETTING_TOKEN';
    }
};

const claimFaucet = async (address) => {
    let success = false;

    while (!success) {
        const bearer = await twocaptcha_turnstile('0x4AAAAAAAc6HG1RMG_8EHSC', 'https://faucet.sonic.game/#/');
        if (bearer == 'ERROR_WRONG_USER_KEY' || bearer == 'ERROR_ZERO_BALANCE' || bearer == 'FAILED_GETTING_TOKEN') {
            success = true;
            return `클레임 실패, ${bearer}`;
        }

        try {
            const res = await fetch(`https://faucet-api.sonic.game/airdrop/${address}/1/${bearer.request}`, {
                headers: {
                    "Accept": "application/json, text/plain, */*",
                    "Content-Type": "application/json",
                    "Accept-Language": "en-US,en;q=0.9,id;q=0.8",
                    "Dnt": "1",
                    "Origin": "https://faucet.sonic.game",
                    "Priority": "u=1, i",
                    "Referer": "https://faucet.sonic.game/",
                    "User-Agent": bearer.useragent,
                    "sec-ch-ua-mobile": "?0",
                    "sec-ch-ua-platform": "Windows",
                }
            }).then(res => res.json());

            if (res.status == 'ok') {
                success = true;
                return `성공적으로 1 SOL을 클레임했습니다!`;
            }
        } catch (error) {
            // 오류 처리
        }
    }
};

const getLoginToken = async (keyPair) => {
    let success = false;
    while (!success) {
        try {
            const message = await fetch(`https://odyssey-api.sonic.game/auth/sonic/challenge?wallet=${keyPair.publicKey}`, {
                headers: defaultHeaders
            }).then(res => res.json());

            const sign = nacl.sign.detached(Buffer.from(message.data), keyPair.secretKey);
            const signature = Buffer.from(sign).toString('base64');
            const publicKey = keyPair.publicKey.toBase58();
            const addressEncoded = Buffer.from(keyPair.publicKey.toBytes()).toString("base64");
            const authorize = await fetch('https://odyssey-api.sonic.game/auth/sonic/authorize', {
                method: 'POST',
                headers: defaultHeaders,
                body: JSON.stringify({
                    'address': `${publicKey}`,
                    'address_encoded': `${addressEncoded}`,
                    'signature': `${signature}`
                })
            }).then(res => res.json());

            const token = authorize.data.token;
            success = true;
            return token;
        } catch (e) {
            // 오류 처리
        }
    }
};

const dailyCheckin = async (keyPair, auth) => {
    let success = false;
    while (!success) {
        try {
            const data = await fetch(`https://odyssey-api.sonic.game/user/check-in/transaction`, {
                headers: {
                    ...defaultHeaders,
                    'authorization': `${auth}`
                }
            }).then(res => res.json());

            if (data.message == 'current account already checked in') {
                success = true;
                return '오늘 이미 체크인 했습니다!';
            }

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, "base64");
                const transaction = Transaction.from(transactionBuffer);
                const signature = await sendTransaction(transaction, keyPair);
                const checkin = await fetch('https://odyssey-api.sonic.game/user/check-in', {
                    method: 'POST',
                    headers: {
                        ...defaultHeaders,
                        'authorization': `${auth}`
                    },
                    body: JSON.stringify({
                        'hash': `${signature}`
                    })
                }).then(res => res.json());

                success = true;
                return `성공적으로 체크인 완료, ${checkin.data.accumulative_days}일차!`;
            }
        } catch (e) {
            // 오류 처리
        }
    }
};

const dailyMilestone = async (auth, stage) => {
    let success = false;
    while (!success) {
        try {
            await fetch('https://odyssey-api.sonic.game/user/transactions/state/daily', {
                method: 'GET',
                headers: {
                    ...defaultHeaders,
                    'authorization': `${auth}`
                }
            });

            const data = await fetch('https://odyssey-api.sonic.game/user/transactions/rewards/claim', {
                method: 'POST',
                headers: {
                    ...defaultHeaders,
                    'authorization': `${auth}`
                },
                body: JSON.stringify({
                    'stage': stage
                })
            }).then(res => res.json());

            if (data.message == 'interact rewards already claimed') {
                success = true;
                return `마일스톤 ${stage} 이미 클레임했습니다!`;
            }

            if (data.data) {
                success = true;
                return `성공적으로 마일스톤 ${stage} 보상을 클레임했습니다.`
            }
        } catch (e) {
            // 오류 처리
        }
    }
};

const openBox = async (keyPair, auth) => {
    let success = false;
    while (!success) {
        try {
            const data = await fetch(`https://odyssey-api.sonic.game/user/rewards/mystery-box/build-tx`, {
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            }).then(res => res.json());

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, "base64");
                const transaction = Transaction.from(transactionBuffer);
                transaction.partialSign(keyPair);
                const signature = await sendTransaction(transaction, keyPair);
                const open = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/open', {
                    method: 'POST',
                    headers: {
                        ...defaultHeaders,
                        'authorization': auth
                    },
                    body: JSON.stringify({
                        'hash': signature
                    })
                }).then(res => res.json());

                success = true;
                return `성공적으로 미스터리 박스를 열었습니다, ${open.data.reward}!`;
            }
        } catch (e) {
            // 오류 처리
        }
    }
};

// 각 개인키에 대해 처리 수행
(async () => {
    const totalKeys = listAccounts.length;

    for (let i = 0; i < totalKeys; i++) {
        const privateKey = listAccounts[i];
        const keypair = getKeypairFromPrivateKey(privateKey);
        const publicKey = keypair.publicKey.toBase58();
        const initialBalance = await connection.getBalance(keypair.publicKey);
        console.log(`공식키: ${publicKey}`);
        console.log(`초기 잔액: ${initialBalance}`);
        const getToken = await getLoginToken(keypair);
        const getdaily = await dailyCheckin(keypair, getToken);
        console.log(getdaily);

        const progress = ((i + 1) / totalKeys * 100).toFixed(2);
        console.log(`처리 진행 상태: ${progress}% (${i + 1}/${totalKeys})`);

        await new Promise(resolve => setTimeout(resolve, 1000));
    }
})();
EOF

echo -e "${YELLOW}Node.js 스크립트를 작성했습니다.${NC}"

# Node.js 스크립트 실행
echo -e "${GREEN}Node.js 스크립트를 실행합니다...${NC}"
node --no-deprecation sonic-daily.mjs

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
